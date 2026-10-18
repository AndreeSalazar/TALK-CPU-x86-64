# Flappy Metal — first drawing milestone

An original rectangle-based scene inspired by a side-scrolling bird game. This
milestone draws a bird, clouds, pipes and ground after ExitBootServices. It is
**a static preview**, not yet a playable game: no physics, timer, input, scoring
or restart is implemented.

From the repository root:

```powershell
.\jugar.ps1
.\jugar.ps1 -Comprobar
```

The first command opens QEMU with the scene. It intentionally halts with the
image visible; close the QEMU window to exit. The second boots three separate
test VMs, checks actual framebuffer contents, and leaves the virtual image in
normal scene state. No physical SSD or UEFI entry is changed.

## Rendering contract

- Hand-written x86-64 instructions in `scene.hex`; rectangle data in `scene.json`.
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
- Packet: 1300 bytes including the 24-byte FAGRAW64 header; body entry 0, within
  the existing bridge's 4072-byte limit. Context +0xB0 is an experimental scene
  witness: 1 means completed, 2 means a rectangle was rejected.
- The payload halts itself and does not return into the bridge's text renderer;
  the bridge's payload-returned flag remains zero. No firmware services are used
  by the scene. This does not replace the platform firmware or install a complete
  exception/interrupt environment.

## Tests and next work

The normal case compares every framebuffer pixel with a separately constructed
rectangle reference. `outside` injects a coordinate that overflows on centering;
`empty` injects zero width. Both must halt with rejection marker 2, drawing only
the valid initial dark background. These checks exposed and fixed the initial
centering overflow bug.

[Screenshots and reports](../../EVIDENCIAS/FLAPPY_METAL/LEEME.md) preserve the actual
QEMU result. No new physical game test is claimed.

Next: own exception handling, versioned drawing ABI, numeric CASM operations,
fixed-step timing and input, then movement/collision. The game's source should
use CASM only after the language and verifier support those operations. The
[project plan](../../docs/PLAN-ORQUESTADOR.md) separates these steps from real
USB keyboard support and the research into firmware from RESET.
