"""Casos negativos de estructura y expresiones; no ejecuta componentes AMD."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import zipfile

spec = importlib.util.spec_from_file_location('trace_msi', Path(__file__).with_name('trazar-inicio-msi.py'))
trace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trace)
passed = []


def rejects(name, function):
    try:
        function()
    except ValueError:
        passed.append(name)
        return
    raise AssertionError(name + ': no rechazo la entrada')


rejects('GUID truncado', lambda: trace.pei_depex(b'\x02\x00\x08'))
rejects('AND sin operandos', lambda: trace.pei_depex(b'\x03\x08'))
rejects('Opcode DXE rechazado en PEI', lambda: trace.pei_depex(b'\x00\x08'))
rejects('Falta END', lambda: trace.pei_depex(b'\x06'))
rejects('Bytes despues de END', lambda: trace.pei_depex(b'\x06\x08\x06'))
guid_bytes = bytes(range(16))
expression = trace.pei_depex(b'\x02' + guid_bytes + b'\x08')
assert len(expression['ReferencedPPIs']) == 1 and expression['RuntimeSatisfied'] is None
passed.append('Expresion valida sin asumir disponibilidad de PPI')

path = Path(sys.argv[1])
before = hashlib.sha256(path.read_bytes()).hexdigest()
with zipfile.ZipFile(path) as archive:
    data = archive.read('7C52v2C/E7C52AMS.2C0')
combo = 0x10a8000
changed = bytearray(data)
changed[combo + 32] ^= 1
rejects('Combo alterada', lambda: trace.trace_domain(changed, trace.DOMAIN))
changed = bytearray(data)
struct.pack_into('<Q', changed, combo + 40, 1 << 40)
count = struct.unpack_from('<I', changed, combo + 8)[0]
struct.pack_into('<I', changed, combo + 4, trace.inventory.fletcher32(changed[combo + 8:combo + 32 + count * 16]))
rejects('Enlace fuera del dominio con checksum correcto', lambda: trace.trace_domain(changed, trace.DOMAIN))
changed = bytearray(data)
struct.pack_into('<I', changed, combo + 36, 0xdeadbeef)
struct.pack_into('<I', changed, combo + 4, trace.inventory.fletcher32(changed[combo + 8:combo + 32 + count * 16]))
result = trace.trace_domain(changed, trace.DOMAIN)
node = next(n for n in result['Nodes'] if n['Offset'] == combo)
assert node['Entries'][0]['CandidateGeneration'] == 'No clasificada aqui'
assert node['Entries'][0]['SelectedForInstalledCPU'] is None
passed.append('ID desconocido no seleccionado como CPU instalada')
result = trace.trace_domain(data, trace.DOMAIN)
for table_offset in (0x1462000, 0x15e2000):
    target = next(n for n in result['Nodes'] if n['Offset'] == table_offset)
    assert next(e for e in target['Entries'] if e['Type'] == 0x62)['Target'] == 0x1d82000
passed.append('Modo de directorio conserva el dominio correcto')
assert hashlib.sha256(path.read_bytes()).hexdigest() == before
passed.append('Paquete original sin cambios')
Path('build/analisis-msi/pruebas-trazado.json').write_text(json.dumps(dict(Passed=len(passed), Total=11, Cases=passed), indent=2) + '\n', encoding='utf-8')
assert len(passed) == 11
print('OK: 11 comprobaciones del trazado y DEPEX.')
