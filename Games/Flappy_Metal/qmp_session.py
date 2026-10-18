"""Owned QEMU process with a pipe-only QMP channel for game regression tests."""
import json
from pathlib import Path
import queue
import re
import shutil
import subprocess
import threading
import time


class Session:
    def __init__(self,root,qemu,prefix,display='none'):
        self.root,self.prefix=Path(root),Path(prefix)
        qemu=Path(qemu);share=qemu.parent/'share'
        variables=Path(str(prefix)+'-vars.fd')
        shutil.copyfile(share/'edk2-i386-vars.fd',variables)
        # Exercise the actual interactive title: QEMU treats commas as suboptions.
        launcher=(self.root/'Games/Flappy_Metal/run.ps1').read_text(encoding='utf-8-sig')
        titles=re.findall(r"-name '([^']+)'",launcher)
        if len(titles)!=1:raise ValueError('Expected one interactive QEMU title')
        self.process=subprocess.Popen([str(qemu),'-name',titles[0],'-machine','pc','-cpu','qemu64','-accel','tcg','-m','256M','-smp','1',
            '-drive',f'if=pflash,format=raw,unit=0,readonly=on,file={share/"edk2-x86_64-code.fd"}',
            '-drive',f'if=pflash,format=raw,unit=1,file={variables}',
            '-drive',f'file={self.root/"build/puente-normal.img"},format=raw,if=ide,snapshot=on',
            '-vga','std','-display',display,'-serial','none','-qmp','stdio','-monitor','none','-no-reboot'],
            stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8',cwd=root,
            creationflags=subprocess.CREATE_NO_WINDOW)
        self.responses=queue.Queue();self.sequence=0
        def reader():
            for line in self.process.stdout:
                try:self.responses.put(json.loads(line))
                except ValueError:pass
        threading.Thread(target=reader,daemon=True).start()
        self.command('qmp_capabilities')

    def command(self,name,arguments=None):
        self.sequence+=1
        request=dict(execute=name,id=self.sequence)
        if arguments is not None:request['arguments']=arguments
        self.process.stdin.write(json.dumps(request)+'\n');self.process.stdin.flush()
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            reply=self.responses.get(timeout=max(0.01,deadline-time.monotonic()))
            if reply.get('id')==self.sequence:
                if 'error' in reply:raise RuntimeError(reply['error'])
                return reply['return']
        raise TimeoutError(name)

    def monitor(self,command):
        return self.command('human-monitor-command',{'command-line':command})

    def memory(self,address,size,label):
        path=Path(str(self.prefix)+f'-{label}.bin')
        self.monitor(f'pmemsave {address:#x} {size:#x} "{path.as_posix()}"')
        data=path.read_bytes()
        if len(data)!=size:raise ValueError('Truncated guest memory dump')
        return data

    def key(self,name,hold=50):
        self.command('send-key',{'keys':[{'type':'qcode','data':name}],'hold-time':hold})

    def screenshot(self,name):
        self.command('screendump',{'filename':str(self.prefix.parent/name),'format':'png'})

    def close(self):
        if self.process.poll() is None:
            try:self.command('quit');self.process.wait(timeout=5)
            except Exception:self.process.kill();self.process.wait()
        self.process.stdin.close();self.process.stdout.close();self.process.stderr.close()
