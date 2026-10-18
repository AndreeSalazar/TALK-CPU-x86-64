"""Prueba real del puente bajo OVMF/QEMU usando QMP por tuberias, sin puertos TCP."""
import argparse
import hashlib
import json
import msvcrt
from pathlib import Path
import queue
import re
import shutil
import struct
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--casos', nargs='+', default=['normal'])
parser.add_argument('--qemu', default='C:/Program Files/qemu/qemu-system-x86_64.exe')
args = parser.parse_args()
# Evitar que dos ejecuciones mezclen capturas, contexto o resultados.
lock_handle = (ROOT / 'build/puente-test.lock').open('a+b')
try:
    if lock_handle.seek(0, 2) == 0:
        lock_handle.write(b'0')
        lock_handle.flush()
    lock_handle.seek(0)
    msvcrt.locking(lock_handle.fileno(), msvcrt.LK_NBLCK, 1)
except OSError as error:
    raise SystemExit('Ya hay una prueba del puente en ejecucion.') from error
qemu = Path(args.qemu)
share = qemu.parent / 'share'
results = []


def run(case):
    image = ROOT / 'build' / f'puente-{case}.img'
    before = hashlib.sha256(image.read_bytes()).hexdigest()
    prefix = ROOT / 'build' / f'puente-{case}'
    variables = Path(str(prefix) + '-vars.fd')
    shutil.copyfile(share / 'edk2-i386-vars.fd', variables)
    process = subprocess.Popen([
        str(qemu), '-machine', 'pc', '-cpu', 'qemu64', '-accel', 'tcg', '-m', '256M', '-smp', '1',
        '-drive', f'if=pflash,format=raw,unit=0,readonly=on,file={share / "edk2-x86_64-code.fd"}',
        '-drive', f'if=pflash,format=raw,unit=1,file={variables}',
        '-drive', f'file={image},format=raw,if=ide,snapshot=on',
        '-vga', 'std', '-display', 'none', '-serial', f'file:{prefix}-serial.log',
        '-qmp', 'stdio', '-monitor', 'none', '-no-reboot',
        '-d', 'guest_errors,int', '-D', str(prefix) + '-cpu.log'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding='utf-8', cwd=ROOT,
        creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0)
    messages = queue.Queue()
    def reader():
        for line in process.stdout:
            try:
                messages.put(json.loads(line))
            except ValueError:
                pass
    threading.Thread(target=reader, daemon=True).start()
    sequence = 0

    def command(name, arguments=None):
        nonlocal sequence
        sequence += 1
        request = {'execute': name, 'id': sequence}
        if arguments is not None:
            request['arguments'] = arguments
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            response = messages.get(timeout=max(0.01, deadline - time.monotonic()))
            if response.get('id') == sequence:
                if 'error' in response:
                    raise RuntimeError(str(response['error']))
                return response['return']
        raise TimeoutError(name)

    def memory(address, size, label):
        path = Path(str(prefix) + '-' + label + '.bin')
        command('pmemsave', dict(val=address, size=size, filename=str(path)))
        return path.read_bytes()

    captured = None
    try:
        command('qmp_capabilities')
        deadline = time.monotonic() + 45
        last_registers = ''
        context = None
        saved_context_address = None
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError('QEMU termino: ' + process.stderr.read()[-1000:])
            last_registers = command('human-monitor-command', {'command-line': 'info registers'})
            match = re.search(r'RBP=([0-9a-fA-F]+)', last_registers)
            if saved_context_address is None and case not in ('normal', 'salida'):
                serial = Path(str(prefix) + '-serial.log').read_text(encoding='utf-8', errors='replace')
                if 'Pulse una tecla para volver.' in serial:
                    # Dentro de ReadKeyStroke el compilador de UEFI puede usar RBP.
                    # Localizar la reserva propia por cabecera alineada, solo en RAM de esta VM.
                    for start in range(0xf000000, -1, -0x1000000):
                        block = memory(start, 0x1000000, 'scan')
                        for page in range(0, len(block) - 0xb0, 4096):
                            if block[page:page + 8] == b'METAL64!' and struct.unpack_from('<Q', block, page + 8)[0] % 4096 == 0:
                                saved_context_address = start + page
                                break
                        if saved_context_address is not None:
                            break
                    Path(str(prefix) + '-scan.bin').unlink(missing_ok=True)
            if match or saved_context_address is not None:
                address = saved_context_address if saved_context_address is not None else int(match[1], 16)
                if 0x100000 <= address <= 256 * 1024 * 1024 - 0x20000:
                    candidate = memory(address, 0xb0, 'context')
                    if candidate[:8] == b'METAL64!':
                        ebs, returned, failed = (struct.unpack_from('<I', candidate, p)[0] for p in (0x78, 0x98, 0x9c))
                        if (failed == 1 or ((returned or failed == 2) and 'HLT=1' in last_registers)):
                            context = candidate
                            captured = address
                            break
            time.sleep(0.1)
        command('screendump', {'filename': str(prefix) + '.png', 'format': 'png'})
        Path(str(prefix) + '-registers.txt').write_text(last_registers, encoding='utf-8')
        if context is None:
            raise AssertionError('No se alcanzo contexto final; revisar captura y registro CPU')
        ebs, returned, failed = (struct.unpack_from('<I', context, p)[0] for p in (0x78, 0x98, 0x9c))
        if case == 'salida':
            attempts_left, attempted = (struct.unpack_from('<I', context, p)[0] for p in (0x6c, 0x7c))
            assert (ebs, returned, failed, attempts_left, attempted) == (0, 0, 2, 0, 1)
            assert 'HLT=1' in last_registers, 'No se detuvo tras agotar reintentos'
            return dict(Case=case, Passed=True, FaultInjection='MapKey cero en copia de prueba',
                        BootServicesExited=False, PayloadReturned=False, BoundedRetries=3)
        if case != 'normal':
            assert (ebs, returned, failed) == (0, 0, 1), 'El paquete rechazado salio de UEFI o ejecuto el programa'
            reason_pointer = struct.unpack_from('<Q', context, 0xa0)[0]
            reason = memory(reason_pointer, 128, 'reason').decode('utf-16-le').split('\0', 1)[0]
            expected = 'no se pudo leer' if case == 'ausente' else 'paquete FAGRAW64 invalido'
            assert expected in reason, f'Rechazo distinto del esperado: {reason}'
            return dict(Case=case, Passed=True, BootServicesExited=False, PayloadReturned=False, Reason=reason)
        assert (ebs, returned, failed) == (1, 1, 0), 'No hubo salida y retorno correcto'
        assert 'CPL=0' in last_registers and 'HLT=1' in last_registers, 'No se detuvo en nivel 0'
        packet = (ROOT / 'build/Puente_Metal/METAL/INICIO.X86').read_bytes()
        code = struct.unpack_from('<Q', context, 8)[0]
        assert memory(code, len(packet) - 24, 'code') == packet[24:], 'No ejecuto la copia exacta del cuerpo propio'
        size, stride = struct.unpack_from('<Q', context, 0x50)[0], struct.unpack_from('<Q', context, 0x60)[0]
        descriptors = memory(captured + 0x1000, size, 'map')
        assert stride >= 40 and size % stride == 0, 'Mapa de memoria invalido'
        regions = [struct.unpack_from('<I4xQQQQ', descriptors, off) for off in range(0, size, stride)]
        assert any(kind == 1 and base <= code and code + 4096 <= base + pages * 4096 for kind, base, virt, pages, attr in regions)
        assert any(kind == 2 and base <= captured and captured + 0x20000 <= base + pages * 4096 for kind, base, virt, pages, attr in regions)
        framebuffer = struct.unpack_from('<Q', context, 0x10)[0]
        scan = struct.unpack_from('<I', context, 0x28)[0]
        pixels = memory(framebuffer, scan * 48 * 4, 'pixels')
        expected = bytearray(len(pixels))
        font = (ROOT / 'build/Puente_Metal/EFI/BOOT/BOOTX64.EFI').read_bytes()[0x2000:0x2800]
        for row, text in enumerate(('METAL64: BootServices cerrados.', 'Hola mundo desde mi .hex!', 'Programa propio retorno. CPU detenida.')):
            for col, character in enumerate(text):
                for y in range(16):
                    bits = font[ord(character) * 16 + y]
                    for x in range(8):
                        if bits & (0x80 >> x):
                            offset = ((row * 16 + y) * scan + col * 8 + x) * 4
                            expected[offset:offset + 4] = b'\xff\xff\xff\0'
        assert pixels == expected, 'Framebuffer distinto del texto propio esperado'
        return dict(Case=case, Passed=True, BootServicesExited=True, PayloadReturned=True,
                    Ring=0, OwnFramebufferTextVerified=True, Context=f'0x{captured:X}',
                    PayloadSHA256=hashlib.sha256(packet[24:]).hexdigest())
    finally:
        if process.poll() is None:
            try:
                command('quit')
                process.wait(timeout=5)
            except Exception:
                process.kill()
                process.wait()
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()
        assert hashlib.sha256(image.read_bytes()).hexdigest() == before, 'La imagen base fue modificada'


for case in args.casos:
    try:
        result = run(case)
    except Exception as error:
        result = dict(Case=case, Passed=False, Error=str(error))
    results.append(result)
    print(json.dumps(result, ensure_ascii=True))
Path('build/puente-test-results.json').write_text(json.dumps(dict(Passed=sum(c['Passed'] for c in results), Total=len(results), Cases=results), indent=2) + '\n', encoding='utf-8')
if not all(c['Passed'] for c in results):
    raise SystemExit(1)
