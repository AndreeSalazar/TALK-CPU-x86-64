"""Package hand-written instructions and rectangle DATA; no instruction generation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def append_hex(body,path):
    for line in path.read_text().splitlines():
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

def verify_game_branches(body,path):
    labels={'fill':0x100,'descriptors':0x200}
    branches=[];pc=0
    for line_number,line in enumerate(path.read_text().splitlines(),1):
        label=re.search(r'; label (\w+)',line)
        if label:
            if label[1] in labels:raise ValueError('Duplicate game label')
            labels[label[1]]=pc
        tokens=line.split(';',1)[0].split()
        branch=re.search(r'; rel(8|32) (\w+)',line)
        if branch:
            size=int(branch[1])//8
            branches.append((pc+len(tokens),size,branch[2],line_number))
        for token in tokens:
            if token.startswith('@'):pc=int(token[1:],16)
            elif token.startswith('='):
                if pc!=int(token[1:],16):raise ValueError('Game offset contract')
            else:pc+=1
    for end,size,target,line_number in branches:
        if target not in labels:raise ValueError(f'Undefined branch label: {target}')
        actual=end+int.from_bytes(body[end-size:end],'little',signed=True)
        if actual!=labels[target]:
            raise ValueError(f'RED [BRANCH-TARGET] line {line_number}: {actual:#x} != {target} ({labels[target]:#x})')
    print(f'GREEN [BRANCHES] {len(branches)} annotated branch/address operands verified; no instruction generation.')
    return len(branches)


def build(case='normal',play=False,game_case='normal'):
    body = bytearray()
    append_hex(body,HERE/'scene.hex')
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
    if play:
        if case!='normal': raise ValueError('Static fault fixtures are not playable packets')
        if game_case in ('ceiling','pipe','wrap','scorecap','clip'):
            append_hex(body,HERE/'fixture.hex')
        append_hex(body,HERE/'game.hex')
        verify_game_branches(body,HERE/'game.hex')
        if game_case in ('ceiling','pipe','wrap','scorecap','clip'):
            values={'ceiling':(256,-1152,324,0),'pipe':(25600,0,150,0),
                    'wrap':(37632,0,-72,0),'scorecap':(37632,0,74,999),'clip':(37632,0,-22,0)}[game_case]
            for offset,value in zip((0x515,0x51F,0x529,0x533),values):
                struct.pack_into('<I',body,offset,value&0xFFFFFFFF)
            if body[0x63D:0x642]!=bytes.fromhex('E8 3E 01 00 00'):raise ValueError('Game reset call contract changed')
            struct.pack_into('<i',body,0x63E,0x500-0x642)
        elif game_case=='timerfault':
            if body[0x9C0:0x9C9]!=bytes.fromhex('B9 80 96 98 00 E4 61 A8 20'):raise ValueError('Timer fixture contract changed')
            struct.pack_into('<I',body,0x9C1,1)
            body[0x9C8]=0
        elif game_case=='keyboardfault':
            if body[0xE85:0xE89]!=bytes.fromhex('E4 64 A8 02'):raise ValueError('Keyboard fixture contract changed')
            body[0xE85:0xE87]=bytes.fromhex('B0 02')
    elif game_case!='normal':raise ValueError('Game fixtures require --play')
    if not 1 <= len(body) <= 4072: raise ValueError('Bridge body size limit')
    if len(body)>3500:print(f'YELLOW [BODY-MARGIN] {len(body)}/4072 bytes; {4072-len(body)} bytes remain.')
    packet=b'FAGRAW64'+struct.pack('<IIII',len(body),0x600 if play else 0,sum(body),0)+body
    output=ROOT/'build/Flappy_Metal'
    output.mkdir(parents=True,exist_ok=True)
    name=('game' if game_case=='normal' else 'game-'+game_case) if play else f'scene-{case}'
    path=output/f'{name}.x86'
    path.write_bytes(packet)
    (output/f'{name}.json').write_text(json.dumps(dict(Case=game_case if play else case,Playable=play,EntryOffset=0x600 if play else 0,Bytes=len(packet),BodyBytes=len(body),Rectangles=len(shapes),SHA256=hashlib.sha256(packet).hexdigest(),InstructionSource='Games/Flappy_Metal/scene.hex + game.hex' if play else 'Games/Flappy_Metal/scene.hex',TestFixture=game_case!='normal',PhysicalTest=False),indent=2)+'\n')
    print(f'GREEN [SCENE] {path.name}: {len(packet)} bytes; {len(shapes)} rectangles; case={case}')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',choices=['normal','outside','empty'],default='normal')
    parser.add_argument('--play',action='store_true')
    parser.add_argument('--game-case',choices=['normal','ceiling','pipe','wrap','scorecap','clip','timerfault','keyboardfault'],default='normal')
    args=parser.parse_args()
    build(args.case,args.play,args.game_case)
