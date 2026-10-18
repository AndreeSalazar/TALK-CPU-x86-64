"""Package hand-written instructions and rectangle DATA; no instruction generation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def build(case='normal'):
    body = bytearray()
    for line in (HERE/'scene.hex').read_text().splitlines():
        for token in line.split(';', 1)[0].split():
            if re.fullmatch(r'[@=][0-9A-Fa-f]+', token):
                target = int(token[1:], 16)
                if token[0] == '=':
                    if len(body) != target: raise ValueError(f'Offset {len(body):X} != {target:X}')
                else:
                    if len(body) > target: raise ValueError('Backward offset')
                    body.extend(bytes(target-len(body)))
            elif re.fullmatch(r'[0-9A-Fa-f]{2}', token): body.append(int(token,16))
            else: raise ValueError(f'Invalid HEX token {token}')
    spec=json.loads((HERE/'scene.json').read_text())
    if spec['Canvas'] != [640,360]: raise ValueError('Canvas contract changed')
    shapes=spec['Rectangles']
    if not 1 <= len(shapes) <= 128: raise ValueError('Rectangle count outside contract')
    body.extend(struct.pack('<I',len(shapes)))
    for index,(x,y,w,h,color) in enumerate(shapes):
        if not all(type(v) is int for v in (x,y,w,h)) or not (0<=x<640 and 0<=y<360 and 0<w<=640-x and 0<h<=360-y): raise ValueError('Rectangle outside canvas')
        if not re.fullmatch('[0-9A-F]{6}',color): raise ValueError('Invalid RGB color')
        if index == 0:
            if case == 'outside': x=0xFFFFFFFF
            if case == 'empty': w=0
        body.extend(struct.pack('<IIIII',x,y,w,h,int(color,16)))
    if not 1 <= len(body) <= 4072: raise ValueError('Bridge body size limit')
    packet=b'FAGRAW64'+struct.pack('<IIII',len(body),0,sum(body),0)+body
    output=ROOT/'build/Flappy_Metal'
    output.mkdir(parents=True,exist_ok=True)
    path=output/f'scene-{case}.x86'
    path.write_bytes(packet)
    (output/f'scene-{case}.json').write_text(json.dumps(dict(Case=case,Bytes=len(packet),BodyBytes=len(body),Rectangles=len(shapes),SHA256=hashlib.sha256(packet).hexdigest(),InstructionSource='Games/Flappy_Metal/scene.hex',PhysicalTest=False),indent=2)+'\n')
    print(f'GREEN [SCENE] {path.name}: {len(packet)} bytes; {len(shapes)} rectangles; case={case}')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',choices=['normal','outside','empty'],default='normal')
    build(parser.parse_args().case)
