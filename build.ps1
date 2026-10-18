# build.ps1 — convierte un archivo .hex comentado en bytes crudos.
# No ensambla ni añade nada: solo copia los bytes que tú escribiste.
#
#   4D 5A   byte en hexadecimal
#   ; ...   comentario
#   @200    rellena con 00 hasta el offset 0x200
#   =058    falla si no estamos exactamente en el offset 0x58
#
# Uso:  powershell -ExecutionPolicy Bypass -File build.ps1 [entrada.hex] [salida]

param(
    [string]$In  = "src\hola.hex",
    [string]$Out = "build\EFI\BOOT\BOOTX64.EFI"
)

$ErrorActionPreference = "Stop"
$bytes = New-Object System.Collections.Generic.List[byte]
$n = 0

foreach ($line in Get-Content -Encoding UTF8 $In) {
    $n++
    $code = ($line -split ';', 2)[0]
    foreach ($tok in ($code -split '\s+' | Where-Object { $_ })) {
        if ($tok -match '^@([0-9A-Fa-f]+)$') {
            $target = [Convert]::ToInt32($Matches[1], 16)
            if ($bytes.Count -gt $target) {
                throw ("línea {0}: ya vamos en 0x{1:X3}, no se puede rellenar hasta 0x{2:X3}" -f $n, $bytes.Count, $target)
            }
            while ($bytes.Count -lt $target) { $bytes.Add(0) }
        }
        elseif ($tok -match '^=([0-9A-Fa-f]+)$') {
            $target = [Convert]::ToInt32($Matches[1], 16)
            if ($bytes.Count -ne $target) {
                throw ("línea {0}: se esperaba offset 0x{1:X3} pero vamos en 0x{2:X3}" -f $n, $target, $bytes.Count)
            }
        }
        elseif ($tok -match '^[0-9A-Fa-f]{2}$') {
            $bytes.Add([Convert]::ToByte($tok, 16))
        }
        else {
            throw ("línea {0}: token inválido '{1}'" -f $n, $tok)
        }
    }
}

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
[IO.File]::WriteAllBytes((Join-Path (Get-Location) $Out), $bytes.ToArray())
"{0} bytes -> {1}" -f $bytes.Count, $Out
