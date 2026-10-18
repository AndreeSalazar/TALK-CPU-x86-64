# First physical probe: static graphics

Windows identifies the available keyboards as USB/HID; the user confirmed there
is no PS/2 keyboard. The interactive game currently polls PS/2 and PIT in QEMU.
This physical probe therefore uses the port-I/O-free static picture, not the
interactive game. USB legacy emulation is not assumed to work after BootServices.

The probe leaves the tested hello entry and payload in place. Its separate files:

```text
A:\EFI\ORQUESTADOR\FLAPPY.EFI
A:\METAL\FLAPPY.X86
```

Boot entry: **Flappy Metal (prueba visual)**. It is added at the end, without
changing existing boot order or rebooting automatically. The normal Windows
Boot Manager and previous **Orquestador del Metal (prueba)** remain available.

## Preparation and installation

From the repository root:

```powershell
.\Games\Flappy_Metal\prepare-pc.ps1 -Check
.\tools\install\copiar-puente.ps1 -Destino A:\ -Profile FlappyPreview
.\tools\install\registrar-puente.ps1 -Destino A:\ -Profile FlappyPreview
```

Preparation pins the base EFI and static packet to their reviewed evidence
hashes. The only EFI changes are two equal-length UTF-16 literals: the payload
path and its file-read error text. Machine instructions and font bytes remain
identical. The new path and packet are booted under QEMU, with exact framebuffer
comparison, before physical copying. The package is isolated under
`build/Flappy_Metal/PC_PREVIEW` and cannot be mistaken for the normal game packet.

Both installers keep their original Hello profile by default. FlappyPreview is
explicit and uses separate files, firmware entry and installation logs. No
formatting, partition conversion or chip flashing is performed.

## Manual physical test

1. Save your work and reboot manually.
2. Use F11 to select **Flappy Metal (prueba visual)**.
3. Expect the static bird/pipes/ground picture centered on a dark background.
4. Photograph the whole screen, including any error instead of the picture.
5. The CPU intentionally halts with the picture visible. Reset manually and
   select Windows Boot Manager to return to Windows.

Space and Enter do not control this picture. A frozen picture is the expected
result; it does not prove real-PC game timing or USB input. The user has now supplied a physical photo showing this static scene on the
target PC; see the [physical record](../../EVIDENCIAS/PC_REAL/FLAPPY_VISUAL/LEEME.md).
The photograph does not verify interactive input, timing or long-term stability.

The next prerequisite for real interactive gameplay is a USB host/HID path, or
a supported physical PS/2 keyboard plus verified clock/controller behavior.
The QEMU-only interactive game remains available with `jugar.ps1`.
