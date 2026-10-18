# Development tools

Run commands from the repository root. Everyday entry points remain there:
`iniciar.ps1`, `iniciar-puente.ps1`, `jugar.ps1`, `preparar.ps1` and
`clean-workspace.ps1`.

| Directory | Purpose |
|---|---|
| build | HEX conversion, bridge construction and virtual FAT32 images |
| tests | QEMU ROM/bridge regression tests |
| qemu | Detailed ROM launcher and monitor harness |
| install | Physical volume copying and separate firmware boot entry |
| analysis | Offline MSI inventory/tracing, their tests and PE inspection |
| evidence | Copy completed QEMU reports/screenshots into evidence storage |

Examples:

```powershell
.\tools\tests\test-firmware.ps1
.\tools\analysis\analizar-msi.ps1
.\tools\install\copiar-puente.ps1 -Destino A:\
```

Installation tools affect the explicitly chosen volume/firmware entry; testing
and game preview commands use virtual images. Paths changed during the cleanup;
use the current README commands rather than historical shell history.
