# Flappy Metal — playable QEMU prototype

**Physical status:** a separate static graphics probe is installed on A: BMO as
**Flappy Metal (prueba visual)**. USB-only keyboard availability was confirmed;
the interactive real-PC game is not installed. See [PC-PREVIEW.md](PC-PREVIEW.md)
and the [installation record](../../EVIDENCIAS/PC_REAL/FLAPPY_VISUAL/LEEME.md).

An original rectangle-based game running after ExitBootServices. It now has
gravity, upward impulse, moving pipes, collisions, score and restart. The game
polls QEMU's PS/2 keyboard and PIT directly, with maskable interrupts disabled.
No host game engine or firmware input/timer API runs the game loop.

From the repository root:

```powershell
.\jugar.ps1
.\jugar.ps1 -Comprobar
.\jugar.ps1 -Estatico
```

The first command opens the playable game. Click/focus the QEMU window before
typing. The second tests the static scene, keyboard-driven gameplay and injected
guard fixtures, then leaves the normal game image ready. The third preserves
the original static preview. No physical SSD or UEFI entry is changed.

| Key | Action |
|---|---|
| Space | Start / flap; release before the next flap |
| Enter | Reset to the ready screen |
| Escape | Stop intentionally with the last screen visible |
| F12 | Cooperative pause/resume, also used by regression snapshots |

Collision shows GAME OVER and turns the bird red. Score increases when a pipe
passes the bird and saturates at 999. Close the QEMU window to exit; Escape
halts the guest CPU, not QEMU.

## Rendering contract

- Hand-written x86-64 instructions in `scene.hex` and `game.hex`; data in `scene.json`.
  `build.py` copies those instructions and serializes data, without assembling or
  generating instructions. This first renderer is not emitted by CASM yet.
- 640×360 canvas centered on the bridge's active framebuffer, with a dark border
  filling the rest of the visible screen. Thirty-eight rectangles form the scene.
- Uses the inherited metal64 context for framebuffer, width, height, stride and
  pixel format. Supports the bridge's direct 32-bit RGB/BGR formats. Current
  QEMU evidence covers format 1 (BGR), 1280×800, stride 1280; other modes are not
  claimed as physically tested.
- Rejects unsigned coordinate overflow during centering. The rectangle routine
  rejects zero dimensions and regions outside the framebuffer before storing.
  Byte offsets use stride, not just visible width.
- Static packet: 1300 bytes, entry 0. Playable packet: 4088 bytes, body entry
  0x600 and body size 4064 of the allowed 4072 bytes. Only eight body bytes remain;
  the packager warns rather than weakening that limit. Internal padding may be
  reused after reviewing layout contracts; otherwise growth needs compaction or
  a jointly revised loader/packet contract.
- The playable payload stops on Escape or a detected peripheral timeout and does not return into the bridge's text renderer;
  the bridge's payload-returned flag remains zero. No firmware services are used
  by the scene. This does not replace the platform firmware or install a complete
  exception/interrupt environment.

## Timing, input and state contract

The controller uses a 640×360 logical canvas and 8.8 fixed-point vertical motion:
gravity 64 units/step, flap velocity -1152, downward speed capped at 1536. AABB
collision uses the bird's 57×30 enclosing box and pipe openings. Pipes move two
pixels per step, wrap after leaving the canvas and are clipped at the edges.

PIT channel 2 is armed with count 19886 for each frame, approximately 1/60 second.
Input, simulation and drawing run within that budget, followed by a bounded
wait for completion. This caps tick rate around 60 when rendering fits; under
load the simulation slows instead of catching up. It is not hard real-time or
a calibrated real-PC clock. Polling consumes CPU while waiting; no idle/power
optimization is claimed. Speaker output remains disabled.

The i8042 setup and timer wait have finite retry budgets. Timeout shows
KEYBOARD FAILED or TIMER FAILED and halts. Input reads at most 16 scan bytes per
poll and ignores auxiliary-device data. Make/break tracking prevents held-key
repeat from adding flaps or repeated restarts. This is the QEMU PC scan-set-1
path, not a USB HID/xHCI driver for the real machine.

App-specific workspace, separate from the bridge service table at +0x100:

| Offset | Meaning |
|---|---|
| +0xB0 | GAM1 signature; replaces the static-scene witness only in game mode |
| +0xB4 / +0xB8 / +0xBC | Mode (ready/flying/game-over/stopped), frame count, held keys |
| +0xC0 / +0xC4 | Fixed-point bird Y and signed velocity |
| +0xC8 / +0xCC / +0xD0 | Pipe positions and score |
| +0xD4 / +0xD8 / +0xDC | Restart count, flap count, collision/draw reason |
| +0xE0 / +0xE4 / +0xE8 | Timer fault, keyboard fault, cooperative pause handshake |
| +0xEC / +0xF0 / +0xF4 | Last scan byte, scan count, simulation-step count |

Mode values are 0/1/2/3. Collision reasons are floor=1, ceiling=2, pipe=3,
draw rejection=4. These are experimental application fields, not a public ABI
for arbitrary third-party payloads. Code/data in the payload page remain unchanged.

## Tests and remaining work

The normal case compares every framebuffer pixel with a separately constructed
rectangle reference. `outside` injects a coordinate that overflows on centering;
`empty` injects zero width. Both must halt with rejection marker 2, drawing only
the valid initial dark background. These checks exposed and fixed the initial
centering overflow bug.

Seven interactive checks cover ready rendering, PIT pacing, flap edge/gravity,
collision, restart, moving pipes/score and Escape halt. Seven isolated fixtures
cover ceiling, pipe collision, wrap, score saturation, clipping, timer timeout
and keyboard timeout. Three original static-scene checks remain. Ready, flight,
game-over and fixture framebuffers are checked pixel-for-pixel with an independent
reference, including text. Screenshots are genuine QMP captures.

Boundary fixtures exposed a missing startup jump across zero padding. It was
fixed; exact step/frame counts now guard that startup path. Fixture instructions
in `fixture.hex` and injected fault patches are used only by test packets, never
the normal game image. No physical game test is claimed.

The packager also verifies 86 annotated relative branch/address operands against
their named destinations, without editing the bytes. Two host checks exercise
valid operands and a corrupted startup jump. This does not disassemble or prove
the safety of every instruction; unannotated short branches remain covered by
the execution tests and review.

Next: own exception handling, versioned drawing ABI and numeric CASM operations.
The current game still inherits firmware GDT/IDT/page tables, uses polling and
does not enable IRQ handling. It is not a complete kernel or recovery system.
The game's source should
use CASM only after the language and verifier support those operations. The
[project plan](../../docs/PLAN-ORQUESTADOR.md) separates these steps from real
USB keyboard support and the research into firmware from RESET.
