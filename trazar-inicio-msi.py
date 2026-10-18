"""Traza offline los dominios de 16 MiB y DEPEX PEI de la referencia MSI 2.C.

Modelo de analisis especifico de este archivo, no un interprete AMD universal.
No selecciona una CPU por aproximacion ni genera una ROM modificada.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import uuid
import zipfile

spec = importlib.util.spec_from_file_location('msi_inventory', Path(__file__).with_name('analizar-firmware-msi.py'))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)
DOMAIN = 0x1000000
KNOWN_PPIS = {
    '01f34d25-4de2-23ad-3ff3-36353ff323f1': 'EFI_PEI_PCD_PPI',
    '2ab86ef5-ecb5-4134-b556-3854ca1fe1b4': 'EFI_PEI_READ_ONLY_VARIABLE2_PPI',
    '9ca93627-b65b-4324-a202-c0b461764543': 'EFI_PEI_SMBUS2_PPI',
}


def pei_depex(data):
    """Decodifica solo PEI; valida pila y END. No presupone PPIs instaladas."""
    stack, tokens, guids = [], [], []
    pos = 0
    while pos < len(data):
        op = data[pos]
        pos += 1
        if op == 2:
            if pos + 16 > len(data):
                raise ValueError('GUID DEPEX truncado')
            guid = str(uuid.UUID(bytes_le=bytes(data[pos:pos + 16])))
            pos += 16
            guids.append(guid)
            tokens.append('PUSH ' + guid)
            stack.append('PPI(' + guid + ')')
        elif op in (3, 4):
            if len(stack) < 2:
                raise ValueError('DEPEX sin dos operandos')
            right, left = stack.pop(), stack.pop()
            name = 'AND' if op == 3 else 'OR'
            tokens.append(name)
            stack.append(f'({left} {name} {right})')
        elif op == 5:
            if not stack:
                raise ValueError('NOT sin operando')
            tokens.append('NOT')
            stack[-1] = 'NOT(' + stack[-1] + ')'
        elif op in (6, 7):
            name = 'TRUE' if op == 6 else 'FALSE'
            tokens.append(name)
            stack.append(name)
        elif op == 8:
            if len(stack) != 1 or pos != len(data):
                raise ValueError('END invalido o datos sobrantes')
            tokens.append('END')
            return dict(Expression=stack[0], Tokens=tokens, ReferencedPPIs=sorted(set(guids)),
                        RuntimeSatisfied=None)
        else:
            raise ValueError(f'Opcode PEI no admitido: {op:#x}')
    raise ValueError('DEPEX sin END')


def trace_domain(data, base):
    end = base + DOMAIN
    if end > len(data) or data[base + 0x20000:base + 0x20004] != bytes.fromhex('aa55aa55'):
        raise ValueError('Falta cabecera EFS en el dominio de referencia')
    nodes, edges, roots = {}, [], []

    def resolve(address, mode, table):
        if mode == 0 and 0xff000000 <= address <= 0xffffffff:
            result = base + address - 0xff000000
        elif mode == 1 and 0 <= address < DOMAIN:
            result = base + address
        elif mode == 2:
            result = table + address
        else:
            return None
        return result if base <= result < end else None

    def walk(off):
        if off in nodes:
            return
        if off is None or not base <= off <= end - 16:
            raise ValueError('Referencia a tabla fuera del dominio')
        sig = data[off:off + 4]
        if sig not in (b'2PSP', b'2BHD', b'$PSP', b'$PL2', b'$BHD', b'$BL2'):
            raise ValueError(f'El enlace no apunta a una tabla: {off:#x}')
        combo = sig in (b'2PSP', b'2BHD')
        header = 32 if combo else 16
        stride = 24 if sig in (b'$BHD', b'$BL2') else 16
        checksum, count = struct.unpack_from('<II', data, off + 4)
        limit = off + header + count * stride
        if not 0 < count <= 512 or limit > end:
            raise ValueError('Tabla referenciada truncada o excesiva')
        if inventory.fletcher32(data[off + 8:limit]) != checksum:
            raise ValueError('Checksum de tabla referenciada invalido')
        if combo and data[off + 16:off + 32] != bytes(16):
            raise ValueError('Reservas de combo no reconocidas')
        info = struct.unpack_from('<I', data, off + 12)[0]
        mode = (info >> (24 if info >> 31 else 29)) & 3
        node = dict(Offset=off, Signature=sig.decode(), ChecksumValid=True,
                    DirectoryAddressMode=None if combo else mode, Entries=[])
        nodes[off] = node  # Evitar recursion infinita; el grafo conserva sus enlaces.
        for n in range(count):
            p = off + header + n * stride
            if combo:
                selector, cpu_id, address = struct.unpack_from('<IIQ', data, p)
                child = resolve(address, 0 if address >= 0xff000000 else 1, off)
                generation = 'Zen3 candidata' if cpu_id in (0xbc0c0000, 0xbc0c0140) else 'No clasificada aqui'
                entry = dict(ID=f'0x{cpu_id:08X}', Selector=selector,
                             CandidateGeneration=generation, Target=child,
                             SelectedForInstalledCPU=None)
                node['Entries'].append(entry)
                edges.append(dict(From=off, To=child, Kind='Combo ID', ID=entry['ID']))
                walk(child)
                continue
            flags, size, raw_address = struct.unpack_from('<IIQ', data, p)
            kind = flags & 255
            entry_mode, address = raw_address >> 62, raw_address & ((1 << 62) - 1)
            effective = mode if mode < 2 else entry_mode
            if sig in (b'$PSP', b'$PL2') and kind in (0x48, 0x4a):
                effective = 1
            target = resolve(address, effective, off)
            fits = target is not None and size <= end - target
            entry = dict(Type=kind, Flags=f'0x{flags:08X}', Bytes=size,
                         RawAddress=f'0x{raw_address:X}', EffectiveAddressMode=effective,
                         Target=target, RangeInsideDomain=fits)
            if fits and size:
                entry['SHA256'] = hashlib.sha256(data[target:target + size]).hexdigest()
            if stride == 24:
                entry['Destination'] = f'0x{struct.unpack_from("<Q", data, p + 16)[0]:X}'
                entry['ResetFlag'] = bool(flags & (1 << 16))
                entry['CopyFlag'] = bool(flags & (1 << 17))
                entry['CompressedFlag'] = bool(flags & (1 << 19))
            node['Entries'].append(entry)
            is_link = ((sig in (b'$PSP', b'$PL2') and kind in (0x40, 0x49)) or
                       (sig in (b'$BHD', b'$BL2') and kind == 0x70))
            if is_link:
                edges.append(dict(From=off, To=target, Kind=f'Type 0x{kind:02X}'))
                walk(target)
    # Campos EFS documentados; solo se siguen firmas de directorio reconocidas.
    for delta in (0x10, 0x14, 0x18, 0x1c, 0x20, 0x28, 0x2c):
        address = struct.unpack_from('<I', data, base + 0x20000 + delta)[0]
        if address in (0, 0xffffffff, 0xfffffffe):
            continue
        target = resolve(address, 0 if address >= 0xff000000 else 1, base + 0x20000)
        if target is not None and data[target:target + 4] in (b'2PSP', b'2BHD', b'$PSP', b'$BHD'):
            roots.append(dict(EFSField=delta, Target=target))
            walk(target)
    if not roots:
        raise ValueError('No hay raices de directorio reconocidas')
    return dict(Base=base, Bytes=DOMAIN, EFS=base + 0x20000, Roots=roots,
                Nodes=sorted(nodes.values(), key=lambda n: n['Offset']), Edges=edges,
                ActiveOnPhysicalCPU=None)


def dependencies(data):
    modules = []
    for volume in inventory.volumes(data):
        for file in volume['VisibleFiles']:
            if file['Type'] != 6:
                continue
            pos, end = file['Offset'] + 24, file['Offset'] + file['Bytes']
            if data[file['Offset'] + 19] & 1:
                pos += 8
            expressions = []
            while pos + 4 <= end:
                size = int.from_bytes(data[pos:pos + 3], 'little')
                kind, sh = data[pos + 3], 4
                if size == 0xffffff:
                    if pos + 8 > end:
                        break
                    size, sh = struct.unpack_from('<I', data, pos + 4)[0], 8
                if size < sh or pos + size > end:
                    break
                if kind == 0x1b:
                    expression = pei_depex(data[pos + sh:pos + size])
                    expression['Offset'] = pos
                    expressions.append(expression)
                pos = (pos + size + 3) & ~3
            modules.append(dict(Offset=file['Offset'], Names=file['VisibleNames'], GUID=file['GUID'],
                                FirmwareVolume=volume['Offset'], Dependencies=expressions,
                                WithoutVisibleDepex=not expressions))
    return modules


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    with zipfile.ZipFile(args.archive) as archive:
        data = archive.read('7C52v2C/E7C52AMS.2C0')
    if len(data) != 2 * DOMAIN:
        raise ValueError('Este modelo de dominios solo corresponde a la referencia de 32 MiB')
    report = dict(ImageSHA256=hashlib.sha256(data).hexdigest(),
                  Domains=[trace_domain(data, base) for base in (0, DOMAIN)],
                  PEIModules=dependencies(data),
                  KnownPPIIdentifiers=KNOWN_PPIS,
                  ActiveCPUSelectionProven=False, PhysicalExecutionTested=False,
                  DomainModel='Dos dominios de 16 MiB inferidos del archivo y sus enlaces; no prueba del mapeo fisico activo',
                  Limits=['GUID DEPEX es una dependencia PPI, no la direccion de una funcion',
                          'Los IDs combo no son el CPUID de Windows',
                          'Zen3 candidata usa clasificacion empirica de PSPTool, no seleccion Vermeer probada',
                          'Sin ejecucion, descompresion ni verificacion criptografica'])
    if hashlib.sha256(args.archive.read_bytes()).hexdigest() != before:
        raise ValueError('Entrada alterada durante el analisis')
    if args.output.resolve() == args.archive.resolve():
        raise ValueError('La salida no puede reemplazar la entrada')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'OK: dos dominios trazados y {len(report["PEIModules"])} modulos PEI examinados; sin seleccion activa supuesta.')


if __name__ == '__main__':
    main()
