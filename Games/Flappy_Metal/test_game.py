"""Exercise real guest keyboard, PIT pacing, physics, collisions and framebuffer."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import time

from qmp_session import Session

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'build/Flappy_Metal'
OFFSETS=dict(Mode=0xB4,Frames=0xB8,Held=0xBC,Y=0xC0,Velocity=0xC4,Pipe1=0xC8,Pipe2=0xCC,
             Score=0xD0,Restarts=0xD4,Flaps=0xD8,Cause=0xDC,TimerFault=0xE0,KeyboardFault=0xE4,
             Pause=0xE8,LastScan=0xEC,ScanCount=0xF0,LogicTicks=0xF4)


def expected_frame(context,state):
    width,height,stride,mode=struct.unpack_from('<IIII',context,0x20)
    assert mode in (0,1)
    def color(rgb):
        r,g,b=bytes.fromhex(rgb)
        return bytes((r,g,b,0) if mode==0 else (b,g,r,0))
    pixels=bytearray(stride*height*4)
    def rect(x,y,w,h,rgb):
        assert 0<=x<width and 0<=y<height and 0<w<=width-x and 0<h<=height-y
        row=color(rgb)*w
        for dy in range(h):
            start=((y+dy)*stride+x)*4
            pixels[start:start+w*4]=row
    rect(0,0,width,height,'0B1423')
    ox,oy=(width-640)//2,(height-360)//2
    for index,shape in enumerate(json.loads((ROOT/'Games/Flappy_Metal/scene.json').read_text())['Rectangles']):
        x,y,w,h,rgb=shape
        if 5<=index<=14:x+=state['Pipe1']-324
        elif 15<=index<=22:x+=state['Pipe2']-544
        elif index>=27:
            y+=state['Y']//256-147
            if state['Mode']==2:rgb='EA5455'
        if x<0:w+=x;x=0
        if w<=0 or x>=640:continue
        w=min(w,640-x)
        rect(ox+x,oy+y,w,h,rgb)
    font=(ROOT/'build/Puente_Metal/EFI/BOOT/BOOTX64.EFI').read_bytes()[0x2000:0x2800]
    def text(x,y,value):
        for char in value:
            for dy in range(16):
                bits=font[ord(char)*16+dy]
                for dx in range(8):
                    start=((y+dy)*stride+x+dx)*4
                    pixels[start:start+4]=b'\xff\xff\xff\0' if bits&(0x80>>dx) else bytes(4)
            x+=8
    text(ox+16,oy+16,'SPACE: FLAP  ENTER: RESTART  ESC: STOP')
    status={0:'READY - SPACE TO START',1:'FLYING',2:'GAME OVER - ENTER TO RESTART',3:'STOPPED'}[state['Mode']]
    if state['TimerFault']:status='TIMER FAILED'
    if state['KeyboardFault']:status='KEYBOARD FAILED'
    text(ox+16,oy+40,status)
    text(ox+500,oy+40,f'SCORE {state["Score"]:03d}')
    return pixels


def test(qemu,fixture='normal'):
    image=ROOT/'build/puente-normal.img'
    image_hash=hashlib.sha256(image.read_bytes()).hexdigest()
    session=Session(ROOT,qemu,OUTPUT/'game-test')
    address=None;cases=[];snapshots=[]
    def state():
        nonlocal address
        if address is None:
            registers=session.monitor('info registers')
            match=re.search(r'RBP=([0-9a-fA-F]+)',registers)
            if not match:return None
            candidate=int(match[1],16)
            if not 0x100000<=candidate<0x10000000-0x20000:return None
            data=session.memory(candidate,0x100,'state')
            if data[:8]!=b'METAL64!' or data[0xB0:0xB4]!=b'GAM1':return None
            address=candidate
        else:data=session.memory(address,0x100,'state')
        result={key:struct.unpack_from('<i' if key in ('Y','Velocity','Pipe1','Pipe2') else '<I',data,off)[0] for key,off in OFFSETS.items()}
        if fixture=='normal' and (result['TimerFault'] or result['KeyboardFault']):raise AssertionError(result)
        return result
    def wait(predicate,timeout=10):
        deadline=time.monotonic()+timeout;last=None
        while time.monotonic()<deadline:
            last=state()
            if last is not None and predicate(last):return last
            time.sleep(0.015)
        raise AssertionError(f'Guest state timeout: {last}')
    def pause(name):
        session.key('f12')
        result=wait(lambda s:s['Pause']==2 and not s['Held']&4)
        session.command('stop')
        data=session.memory(address,0x100,'state')
        base=struct.unpack_from('<Q',data,0x10)[0]
        stride,height=struct.unpack_from('<I',data,0x28)[0],struct.unpack_from('<I',data,0x24)[0]
        actual=session.memory(base,stride*height*4,name+'-pixels')
        assert actual==expected_frame(data,result),f'Pixel mismatch: {name}'
        session.screenshot(name+'.png')
        snapshots.append(dict(Name=name,State=result,PixelsCompared=len(actual)//4,FramebufferSHA256=hashlib.sha256(actual).hexdigest()))
        return result
    def resume():
        session.command('cont');session.key('f12')
        return wait(lambda s:s['Pause']==0 and not s['Held']&4)
    try:
        if fixture!='normal':
            result=wait(lambda s: s['Mode']==3 if fixture in ('timerfault','keyboardfault') else s['Pause']==2,30)
            if fixture in ('timerfault','keyboardfault'):
                wait(lambda s:'HLT=1' in session.monitor('info registers'))
            session.command('stop')
            context=session.memory(address,0x100,'fixture-context')
            code=struct.unpack_from('<Q',context,8)[0]
            packet=(OUTPUT/f'game-{fixture}.x86').read_bytes()
            assert session.memory(code,len(packet)-24,'fixture-code')==packet[24:]
            checks={
                'ceiling':dict(Mode=2,Y=0,Cause=2),
                'pipe':dict(Mode=2,Y=25664,Cause=3,Pipe1=148),
                'wrap':dict(Mode=1,Y=37696,Pipe1=640,Score=0),
                'scorecap':dict(Mode=1,Pipe1=72,Score=999),
                'clip':dict(Mode=1,Pipe1=-24),
                'timerfault':dict(Mode=3,TimerFault=1,KeyboardFault=0),
                'keyboardfault':dict(Mode=3,TimerFault=0,KeyboardFault=1),
            }[fixture]
            assert all(result[key]==value for key,value in checks.items()),(fixture,result,checks)
            if fixture not in ('timerfault','keyboardfault'):
                assert result['LogicTicks']==1 and result['Frames']==0,('Unexpected extra startup step',result)
            base=struct.unpack_from('<Q',context,0x10)[0]
            stride,height=struct.unpack_from('<I',context,0x28)[0],struct.unpack_from('<I',context,0x24)[0]
            pixels=session.memory(base,stride*height*4,'fixture-pixels')
            assert pixels==expected_frame(context,result),fixture
            session.screenshot(f'fixture-{fixture}.png')
            report=dict(Case=fixture,Passed=True,State=result,PixelsCompared=len(pixels)//4,PacketSHA256=hashlib.sha256(packet).hexdigest(),PhysicalTest=False,TestFixture=True)
            (OUTPUT/f'game-test-{fixture}.json').write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps(dict(Case=fixture,Passed=True)))
            return
        ready=wait(lambda s:s['Frames']>=2,30)
        assert ready['Mode']==0 and ready['Y']==147*256
        ready=pause('02-game-ready')
        context=session.memory(address,0x100,'context')
        assert struct.unpack_from('<I',context,0x78)[0]==1
        packet=(OUTPUT/'game.x86').read_bytes()
        code=struct.unpack_from('<Q',context,8)[0]
        assert session.memory(code,len(packet)-24,'code')==packet[24:]
        assert 'CPL=0' in session.monitor('info registers')
        cases.append(dict(Case='ready-render-and-code',Passed=True))
        resume()
        before=state()['Frames'];start=time.monotonic();time.sleep(0.35);after=state()['Frames'];elapsed=time.monotonic()-start
        fps=(after-before)/elapsed
        assert 10<=fps<=85,f'Unexpected PIT pacing: {fps}'
        cases.append(dict(Case='pit-pacing',Passed=True,ObservedTicksPerHostSecond=round(fps,2),Measurement='QEMU/host timing, broad regression bound, not a hardware benchmark'))
        session.key('spc',hold=350)
        flying=wait(lambda s:s['Mode']==1 and s['Flaps']>=1)
        assert flying['Velocity']<0 and flying['Y']<147*256
        time.sleep(0.12)
        assert state()['Flaps']==1,'Held key generated repeated flaps'
        cases.append(dict(Case='space-edge-and-gravity',Passed=True))
        lost=wait(lambda s:s['Mode']==2,8)
        assert lost['Cause'] in (1,2,3)
        pause('03-game-over')
        cases.append(dict(Case='collision-and-game-over',Passed=True,Cause=lost['Cause']))
        resume();session.key('ret')
        restarted=wait(lambda s:s['Mode']==0 and s['Restarts']==1 and not s['Held']&2)
        assert restarted['Y']==147*256 and restarted['Score']==0 and restarted['Pipe1']==324
        cases.append(dict(Case='enter-restart',Passed=True))
        session.key('spc')
        wait(lambda s:s['Mode']==1)
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            current=state()
            assert current['Mode']==1,('Autopilot collision',current)
            if current['Score']>=1:break
            if current['Y']>154*256 and current['Velocity']>0 and not current['Held']&1:session.key('spc',hold=35)
            time.sleep(0.012)
        else:raise AssertionError('No pipe passed')
        scored=pause('04-game-flight')
        assert scored['Score']>=1
        cases.append(dict(Case='moving-pipes-score-and-flight-render',Passed=True,Score=scored['Score']))
        resume();session.key('esc')
        stopped=wait(lambda s:s['Mode']==3)
        wait(lambda s:'HLT=1' in session.monitor('info registers'))
        session.command('stop');session.screenshot('05-game-stopped.png')
        cases.append(dict(Case='escape-defined-halt',Passed=True))
        report=dict(Passed=len(cases),Total=len(cases),Cases=cases,Snapshots=snapshots,
                    PacketSHA256=hashlib.sha256(packet).hexdigest(),BodyBytes=len(packet)-24,
                    BootServicesExited=True,PhysicalTest=False,Target='QEMU pc / qemu64 / TCG / PIT + PS2 polling')
        (OUTPUT/'game-test-results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(dict(Passed=len(cases),Total=len(cases),PacketBytes=len(packet),Score=scored['Score'])))
    except Exception:
        session.screenshot('game-test-failure.png')
        (OUTPUT/'game-failure-registers.txt').write_text(session.monitor('info registers'))
        raise
    finally:
        session.close()
        assert hashlib.sha256(image.read_bytes()).hexdigest()==image_hash


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qemu',default='C:/Program Files/qemu/qemu-system-x86_64.exe')
    parser.add_argument('--fixture',choices=['normal','ceiling','pipe','wrap','scorecap','clip','timerfault','keyboardfault'],default='normal')
    args=parser.parse_args()
    test(args.qemu,args.fixture)
