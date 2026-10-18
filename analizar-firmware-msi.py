"""Inventario de solo lectura; no modifica ROM ni produce una imagen instalable.

Solo biblioteca estandar. Estructuras AMD contrastadas con coreboot/amdfwtool;
volumenes y archivos con el formato PI de UEFI. No es un validador de firmas.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import uuid
import zipfile


def locations(data, signature):
    pos = 0
    while True:
        pos = data.find(signature, pos)
        if pos < 0:
            return
        yield pos
        pos += len(signature)


def fletcher32(data):
    if len(data) % 2:
        raise ValueError('Checksum requiere palabras de 16 bits')
    a = b = 0xffff
    for (word,) in struct.iter_unpack('<H', data):
        a += word
        a = (a & 0xffff) + (a >> 16)
        b += a
        b = (b & 0xffff) + (b >> 16)
    a = (a & 0xffff) + (a >> 16)
    b = (b & 0xffff) + (b >> 16)
    return (b << 16) | a


def directories(data):
    accepted, rejected = [], []
    # Las firmas dentro de codigo o datos no se aceptan sin limites y checksum.
    for signature, stride in ((b'$PSP', 16), (b'$PL2', 16),
                              (b'$BHD', 24), (b'$BL2', 24)):
        for off in locations(data, signature):
            if off + 16 > len(data):
                rejected.append(off)
                continue
            checksum, count = struct.unpack_from('<II', data, off + 4)
            end = off + 16 + count * stride
            if not 0 < count <= 512 or end > len(data):
                rejected.append(off)
                continue
            if fletcher32(data[off + 8:end]) != checksum:
                rejected.append(off)
                continue
            entries = []
            for n in range(count):
                p = off + 16 + n * stride
                flags, size, address = struct.unpack_from('<IIQ', data, p)
                mode, address = address >> 62, address & ((1 << 62) - 1)
                # Solo interpreta modos documentados; no todos los tipos son blobs.
                relative = None
                if mode == 0 and (1 << 32) - len(data) <= address < 1 << 32:
                    relative = address - ((1 << 32) - len(data))
                elif mode == 1:
                    relative = address
                elif mode == 2:
                    relative = off + address
                fits = relative is not None and 0 <= relative <= len(data) and size <= len(data) - relative
                item = dict(Type=flags & 255, Flags=f'0x{flags:08X}', Bytes=size,
                            Address=f'0x{address:X}', AddressMode=mode,
                            ResolvedOffset=relative, RangeInsideImage=fits)
                if fits and size:
                    item['SHA256'] = hashlib.sha256(data[relative:relative + size]).hexdigest()
                if stride == 24:
                    item['Destination'] = f'0x{struct.unpack_from("<Q", data, p + 16)[0]:X}'
                entries.append(item)
            accepted.append(dict(Signature=signature.decode(), Offset=off,
                                 Checksum=f'0x{checksum:08X}', ChecksumValid=True,
                                 Entries=entries))
    return sorted(accepted, key=lambda t: t['Offset']), sorted(rejected)


def volumes(data):
    result = []
    for signature_off in locations(data, b'_FVH'):
        off = signature_off - 40
        if off < 0 or off + 56 > len(data):
            continue
        length = struct.unpack_from('<Q', data, off + 32)[0]
        header = struct.unpack_from('<H', data, off + 48)[0]
        if not 56 <= header <= length or header % 2 or off + length > len(data):
            continue
        if sum(w[0] for w in struct.iter_unpack('<H', data[off:off + header])) & 0xffff:
            continue
        files = []
        pos = (off + header + 7) & ~7
        # Solo FFS visibles; no se descomprimen secciones ni se prueban dependencias.
        while pos + 24 <= off + length:
            raw = data[pos:pos + 24]
            if raw == b'\xff' * 24 or raw == b'\x00' * 24:
                break
            size = int.from_bytes(raw[20:23], 'little')
            file_header = 24
            if raw[19] & 1:
                if size != 0xffffff or pos + 32 > off + length:
                    break
                size = struct.unpack_from('<Q', data, pos + 24)[0]
                file_header = 32
            if size < file_header or pos + size > off + length:
                break
            # Comprobacion de cabecera FFS: omitir estado y checksum del cuerpo.
            if (sum(data[pos:pos + file_header]) - raw[17] - raw[23]) & 255:
                break
            names, section_types = [], []
            section = pos + file_header
            while section + 4 <= pos + size:
                section_size = int.from_bytes(data[section:section + 3], 'little')
                section_type = data[section + 3]
                sh = 4
                if section_size == 0xffffff:
                    if section + 8 > pos + size:
                        break
                    section_size = struct.unpack_from('<I', data, section + 4)[0]
                    sh = 8
                if section_size < sh or section + section_size > pos + size:
                    break
                section_types.append(section_type)
                if section_type == 0x15:
                    names.append(data[section + sh:section + section_size].decode('utf-16-le', errors='replace').rstrip('\0'))
                section = (section + section_size + 3) & ~3
            files.append(dict(Offset=pos, Bytes=size, GUID=str(uuid.UUID(bytes_le=bytes(raw[:16]))),
                              Type=raw[18], State=raw[23], HeaderChecksumValid=True,
                              VisibleNames=names, VisibleSectionTypes=section_types))
            pos = (pos + size + 7) & ~7
        result.append(dict(Offset=off, Bytes=length, HeaderBytes=header,
                           HeaderChecksumValid=True,
                           FilesystemGUID=str(uuid.UUID(bytes_le=bytes(data[off + 16:off + 32]))),
                           VisibleFiles=files))
    return result


def inspect(data):
    tables, rejected = directories(data)
    return dict(Bytes=len(data), SHA256=hashlib.sha256(data).hexdigest(),
                AMDDirectories=tables, RejectedDirectorySignatures=rejected,
                FirmwareVolumes=volumes(data),
                Limits=['Checksum no autentica la imagen ni verifica firmas AMD/MSI',
                        'No se descomprimen modulos ni se resuelven sus dependencias',
                        'Escanear tablas no determina cual usa el Ryzen 5600X',
                        'Una entrada AMD puede ser un valor o reserva, no un blob',
                        'No genera firmware ni demuestra reutilizacion independiente'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    with zipfile.ZipFile(args.archive) as archive:
        # Version y miembro deliberadamente fijos para evitar mezclar placas.
        member = '7C52v2C/E7C52AMS.2C0'
        info = archive.getinfo(member)
        if info.file_size != 32 * 1024 * 1024:
            raise ValueError('La imagen de referencia debe medir 32 MiB')
        data = archive.read(member)  # zipfile comprueba CRC del miembro.
        release = archive.read('7C52v2C/7C52v2x.txt').decode('cp950', errors='replace')
    report = inspect(data)
    report.update(Source='https://download.msi.com/bos_exe/mb/7C52v2C.zip',
                  ZIP_SHA256=before, Member=member, ReleaseNotes=release,
                  PhysicalFirmwareRead=False, FlashWritten=False)
    if hashlib.sha256(args.archive.read_bytes()).hexdigest() != before:
        raise ValueError('El paquete de entrada cambio durante el analisis')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.resolve() == args.archive.resolve():
        raise ValueError('La salida no puede reemplazar el archivo de entrada')
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'OK: {len(report["AMDDirectories"])} tablas AMD y {len(report["FirmwareVolumes"])} volumenes con checksum valido; entrada intacta.')


if __name__ == '__main__':
    main()
