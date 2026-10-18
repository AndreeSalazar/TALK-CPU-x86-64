"""Verify literal branch operands without generating or assembling instructions."""
import hashlib
import json

from build import build,verify_game_branches,HERE,ROOT

build(play=True)
packet=(ROOT/'build/Flappy_Metal/game.x86').read_bytes()
count=verify_game_branches(packet[24:],HERE/'game.hex')
bad=bytearray(packet[24:])
bad[0x648]^=1
try:
    verify_game_branches(bad,HERE/'game.hex')
except ValueError as error:
    assert 'BRANCH-TARGET' in str(error)
else:
    raise AssertionError('Corrupted startup jump was accepted')
report=dict(Passed=2,Total=2,BranchOperands=count,CorruptedStartupBranchRejected=True,
            PacketSHA256=hashlib.sha256(packet).hexdigest())
(ROOT/'build/Flappy_Metal/branch-test-results.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('GREEN [TEST] 2/2 branch-operand checks passed.')
