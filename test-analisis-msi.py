"""Pruebas negativas sobre copias en RAM de la imagen MSI; ninguna escritura de ROM."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import zipfile

spec = importlib.util.spec_from_file_location('msi_analysis', Path(__file__).with_name('analizar-firmware-msi.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
archive_path = Path(sys.argv[1])
archive_hash = hashlib.sha256(archive_path.read_bytes()).hexdigest()
with zipfile.ZipFile(archive_path) as archive:
    original = archive.read('7C52v2C/E7C52AMS.2C0')
tables, _ = module.directories(original)
volumes = module.volumes(original)
if not tables or not volumes:
    raise AssertionError('La referencia no contiene estructuras comprobables')

table = tables[0]
offset = table['Offset']
damaged = bytearray(original)
damaged[offset + 16] ^= 1
accepted, rejected = module.directories(damaged)
assert offset in rejected and all(t['Offset'] != offset for t in accepted), 'Se acepto una tabla alterada'
truncated = original[:offset + 17]
accepted, rejected = module.directories(truncated)
assert offset in rejected and all(t['Offset'] != offset for t in accepted), 'Se acepto una tabla truncada'
damaged = bytearray(original)
damaged[offset + 8:offset + 12] = b'\xff' * 4
accepted, rejected = module.directories(damaged)
assert offset in rejected and all(t['Offset'] != offset for t in accepted), 'No se acoto el numero de entradas'
volume = volumes[0]
damaged = bytearray(original)
damaged[volume['Offset'] + 50] ^= 1
assert all(v['Offset'] != volume['Offset'] for v in module.volumes(damaged)), 'Se acepto cabecera FV alterada'
assert hashlib.sha256(archive_path.read_bytes()).hexdigest() == archive_hash, 'Se modifico la referencia'
output = Path('build/analisis-msi/pruebas.json')
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(dict(Passed=5, Total=5, Cases=[
    'Tabla AMD con entrada alterada rechazada', 'Tabla AMD truncada rechazada',
    'Numero excesivo de entradas rechazado', 'Checksum de volumen FV alterado rechazado',
    'Paquete de entrada sin cambios']), indent=2) + '\n', encoding='utf-8')
print('OK: 5 comprobaciones del analizador; no se escribio la ROM.')
