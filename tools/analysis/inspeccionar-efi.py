"""Inspeccion PE32+ y extraccion de secciones para analisis, sin ejecutarlas."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('file', type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
data = args.file.read_bytes()
before = hashlib.sha256(data).hexdigest()
if len(data) < 64 or data[:2] != b'MZ':
    raise ValueError('Falta cabecera DOS')
pe = struct.unpack_from('<I', data, 60)[0]
if pe > len(data) - 24 or data[pe:pe + 4] != b'PE\0\0':
    raise ValueError('Cabecera PE fuera de limites')
machine, count = struct.unpack_from('<HH', data, pe + 4)
optional_size = struct.unpack_from('<H', data, pe + 20)[0]
optional = pe + 24
if optional_size < 112 or optional + optional_size + count * 40 > len(data):
    raise ValueError('Cabeceras truncadas')
if machine != 0x8664 or struct.unpack_from('<H', data, optional)[0] != 0x20b:
    raise ValueError('Solo se inspecciona PE32+ x64 en esta utilidad')
entry = struct.unpack_from('<I', data, optional + 16)[0]
sections = []
entry_file = None
for n in range(count):
    p = optional + optional_size + n * 40
    virtual_size, rva, raw_size, raw_offset = struct.unpack_from('<IIII', data, p + 8)
    if raw_offset > len(data) or raw_size > len(data) - raw_offset:
        raise ValueError('Seccion fuera de limites')
    if rva <= entry < rva + min(virtual_size, raw_size):
        entry_file = raw_offset + entry - rva
    sections.append(dict(Name=data[p:p + 8].rstrip(b'\0').decode('ascii', errors='replace'),
                         RVA=rva, VirtualBytes=virtual_size, FileOffset=raw_offset,
                         FileBytes=raw_size, Flags=f'0x{struct.unpack_from("<I", data, p + 36)[0]:08X}',
                         SHA256=hashlib.sha256(data[raw_offset:raw_offset + raw_size]).hexdigest()))
if entry_file is None:
    raise ValueError('La entrada no esta respaldada por bytes de una seccion')
args.output.mkdir(parents=True, exist_ok=True)
directory_count = struct.unpack_from('<I', data, optional + 108)[0]
if directory_count > (optional_size - 112) // 8:
    raise ValueError('Directorios PE fuera de cabecera')
directories = [dict(Index=n, RVA=struct.unpack_from('<I', data, optional + 112 + n * 8)[0],
                    Bytes=struct.unpack_from('<I', data, optional + 116 + n * 8)[0]) for n in range(directory_count)]
for n, section in enumerate(sections):
    # Nombre de salida controlado: no usar nombres de seccion como rutas.
    output = args.output / f'section-{n:02d}.bin'
    if output.resolve() == args.file.resolve():
        raise ValueError('La salida no puede sobrescribir la entrada')
    start, size = section['FileOffset'], section['FileBytes']
    output.write_bytes(data[start:start + size])
    section['ExtractedFile'] = output.name
report = dict(Source=str(args.file), SHA256=before, FileBytes=len(data), Machine='x86-64',
              Format='PE32+', Subsystem=struct.unpack_from('<H', data, optional + 68)[0],
              EntryRVA=entry, EntryFileOffset=entry_file,
              ImageBytes=struct.unpack_from('<I', data, optional + 56)[0], Sections=sections,
              NonEmptyDirectories=[d for d in directories if d['RVA'] or d['Bytes']],
              ExtractedCodeIsStandalone=False, Executed=False)
report_path = args.output / 'inspeccion.json'
if report_path.resolve() == args.file.resolve():
    raise ValueError('El informe no puede reemplazar la entrada')
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if hashlib.sha256(args.file.read_bytes()).hexdigest() != before:
    raise ValueError('Se modifico el archivo de entrada')
print(f'OK: PE32+ x64, entrada RVA {entry:#x}, {count} secciones extraidas para analisis.')
