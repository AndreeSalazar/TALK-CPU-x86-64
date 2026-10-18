"""Boot a prepared scene image; verify actual VM pixels and runtime bounds rejection."""
import argparse
import hashlib
import json
from pathlib import Path
import queue
import re
import shutil
import struct
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'build/Flappy_Metal'


def test(case,qemu):
    qemu=Path(qemu)
    image=ROOT/'build/puente-normal.img'
    image_hash=hashlib.sha256(image.read_bytes()).hexdigest()
    prefix=OUTPUT/f'scene-{case}'
    variables=Path(str(prefix)+'-vars.fd')
    shutil.copyfile(qemu.parent/'share/edk2-i386-vars.fd',variables)
    proc=subprocess.Popen([str(qemu),'-machine','pc','-cpu','qemu64','-accel','tcg','-m','256M','-smp','1',
        '-drive',f'if=pflash,format=raw,unit=0,readonly=on,file={qemu.parent / "share/edk2-x86_64-code.fd"}',
        '-drive',f'if=pflash,format=raw,unit=1,file={variables}',
        '-drive',f'file={image},format=raw,if=ide,snapshot=on','-vga','std','-display','none',
        '-serial','none','-qmp','stdio','-monitor','none','-no-reboot'],
        stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8',cwd=ROOT,
        creationflags=subprocess.CREATE_NO_WINDOW)
    responses=queue.Queue()
    def reader():
        for line in proc.stdout:
            try: responses.put(json.loads(line))
            except ValueError: pass
    threading.Thread(target=reader,daemon=True).start()
    sequence=0
    def command(name,arguments=None):
        nonlocal sequence
        sequence+=1
        request=dict(execute=name,id=sequence)
        if arguments is not None: request['arguments']=arguments
        proc.stdin.write(json.dumps(request)+'\n');proc.stdin.flush()
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            response=responses.get(timeout=max(0.01,deadline-time.monotonic()))
            if response.get('id')==sequence:
                if 'error' in response: raise RuntimeError(response['error'])
                return response['return']
        raise TimeoutError(name)
    def memory(address,size,label):
        path=Path(str(prefix)+f'-{label}.bin')
        command('human-monitor-command',{'command-line':f'pmemsave {address:#x} {size:#x} "{path.as_posix()}"'})
        data=path.read_bytes()
        assert len(data)==size
        return data
    try:
        command('qmp_capabilities')
        deadline=time.monotonic()+35
        context=None
        while time.monotonic()<deadline:
            if proc.poll() is not None: raise RuntimeError(proc.stderr.read())
            registers=command('human-monitor-command',{'command-line':'info registers'})
            match=re.search(r'RBP=([0-9a-fA-F]+)',registers)
            if match and 'HLT=1' in registers:
                address=int(match[1],16)
                if 0x100000<=address<0x10000000-0x20000:
                    candidate=memory(address,0xB8,'context')
                    if candidate[:8]==b'METAL64!' and struct.unpack_from('<I',candidate,0xB0)[0] in (1,2):
                        context=candidate; break
            time.sleep(0.1)
        command('screendump',{'filename':str(prefix)+'.png','format':'png'})
        Path(str(prefix)+'-registers.txt').write_text(registers)
        assert context is not None,'Scene did not reach a defined halt; inspect screenshot/registers'
        assert struct.unpack_from('<I',context,0x78)[0]==1 and struct.unpack_from('<I',context,0x9C)[0]==0
        assert 'CPL=0' in registers
        marker=struct.unpack_from('<I',context,0xB0)[0]
        assert marker==(1 if case=='normal' else 2)
        packet=(OUTPUT/f'scene-{case}.x86').read_bytes()
        code=struct.unpack_from('<Q',context,8)[0]
        assert memory(code,len(packet)-24,'code')==packet[24:]
        base=struct.unpack_from('<Q',context,0x10)[0]
        width,height,stride,mode=struct.unpack_from('<IIII',context,0x20)
        assert mode in (0,1) and width>=640 and height>=400
        def color(rgb):
            r,g,b=bytes.fromhex(rgb)
            return bytes((r,g,b,0) if mode==0 else (b,g,r,0))
        actual=memory(base,stride*height*4,'framebuffer')
        expected=bytearray(len(actual))
        # Visible pixels only; padding is verified separately against its zero-initialized state.
        for y in range(height): expected[y*stride*4:(y*stride+width)*4]=color('0B1423')*width
        if case=='normal':
            ox,oy=(width-640)//2,(height-360)//2
            shapes=json.loads((ROOT/'Games/Flappy_Metal/scene.json').read_text())['Rectangles']
            for x,y,w,h,rgb in shapes:
                row=color(rgb)*w
                for dy in range(h):
                    start=((oy+y+dy)*stride+ox+x)*4
                    expected[start:start+w*4]=row
        assert actual==expected,'Framebuffer differs from rectangle reference'
        return dict(Case=case,Passed=True,BootServicesExited=True,Ring=0,SceneReady=marker==1,
                    BoundsRejected=marker==2,Width=width,Height=height,Stride=stride,PixelFormat=mode,
                    FramebufferSHA256=hashlib.sha256(actual).hexdigest(),PacketSHA256=hashlib.sha256(packet).hexdigest(),
                    PixelsCompared=len(actual)//4,PhysicalTest=False)
    finally:
        if proc.poll() is None:
            try: command('quit');proc.wait(timeout=5)
            except Exception: proc.kill();proc.wait()
        proc.stdin.close();proc.stdout.close();proc.stderr.close()
        assert hashlib.sha256(image.read_bytes()).hexdigest()==image_hash,'Virtual base image changed'


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',choices=['normal','outside','empty'],default='normal')
    parser.add_argument('--qemu',default='C:/Program Files/qemu/qemu-system-x86_64.exe')
    args=parser.parse_args()
    case=args.case
    result=test(case,args.qemu)
    (OUTPUT/f'test-{case}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
