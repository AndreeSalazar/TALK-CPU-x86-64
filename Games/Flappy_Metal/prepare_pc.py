"""Prepare a separate static PC probe; preserve the tested hello bridge and payload."""
import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'build/Flappy_Metal/PC_PREVIEW'


def prepare():
    base=(ROOT/'build/Puente_Metal/EFI/BOOT/BOOTX64.EFI').read_bytes()
    tested=json.loads((ROOT/'EVIDENCIAS/PUENTE_UEFI/inspeccion-puente.json').read_text(encoding='utf-8-sig'))
    if hashlib.sha256(base).hexdigest()!=tested['SHA256'].lower():
        raise ValueError('Base EFI differs from the bridge reviewed and tested previously')
    packet=(ROOT/'build/Flappy_Metal/scene-normal.x86').read_bytes()
    golden=json.loads((ROOT/'EVIDENCIAS/FLAPPY_METAL/scene-normal.json').read_text())
    if hashlib.sha256(packet).hexdigest()!=golden['SHA256'].lower():
        raise ValueError('Static preview differs from the reviewed scene packet')
    size,entry,checksum,flags=struct.unpack_from('<IIII',packet,8)
    if packet[:8]!=b'FAGRAW64' or (size,entry,flags)!=(1276,0,0) or size+24!=len(packet) or sum(packet[24:])!=checksum:
        raise ValueError('Only the static, port-I/O-free scene is allowed for this probe')
    modified=bytearray(base)
    changes=[]
    for offset,old,new in (
        (0x1840,'\\METAL\\INICIO.X86\0','\\METAL\\FLAPPY.X86\0'),
        (0x1980,'RED [METAL] no se pudo leer METAL/INICIO.X86\r\n\0','RED [METAL] no se pudo leer METAL/FLAPPY.X86\r\n\0')):
        old,new=old.encode('utf-16-le'),new.encode('utf-16-le')
        if len(old)!=len(new) or base[offset:offset+len(old)]!=old:raise ValueError('EFI literal-data contract changed')
        modified[offset:offset+len(old)]=new
        changes.append(dict(Offset=offset,Bytes=len(old),Kind='UTF16 path/error text only'))
    allowed={n for item in changes for n in range(item['Offset'],item['Offset']+item['Bytes'])}
    if any(a!=b and index not in allowed for index,(a,b) in enumerate(zip(base,modified))):raise ValueError('Unexpected EFI byte change')
    if modified[:0x1800]!=base[:0x1800] or modified[0x2000:]!=base[0x2000:]:raise ValueError('Instructions or font changed')
    files={'EFI/ORQUESTADOR/FLAPPY.EFI':bytes(modified),'METAL/FLAPPY.X86':packet}
    entries=[]
    for name,data in files.items():
        path=OUTPUT/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        entries.append(dict(Ruta=name,Bytes=len(data),SHA256=hashlib.sha256(data).hexdigest().upper()))
    manifest=dict(Nombre='Flappy Metal - prueba visual',Perfil='FlappyPreview',Interactive=False,
                  PhysicalTest=False,BaseEFISHA256=hashlib.sha256(base).hexdigest(),Changes=changes,Archivos=entries)
    (OUTPUT/'manifiesto.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
    (OUTPUT/'LEEME.txt').write_bytes(b'FLAPPY METAL - VISUAL PC PROBE\nStatic picture only. No keyboard or animation.\nSelect the separate boot entry manually. Photograph the screen, then reset manually.\nThe USB keyboard driver and interactive real-PC game are not implemented.\n')
    print('GREEN [PC-PREVIEW] Separate static packet prepared; EFI instructions unchanged. No physical copy performed.')


if __name__=='__main__':prepare()
