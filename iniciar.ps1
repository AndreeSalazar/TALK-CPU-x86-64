# Entrada en español. Conserva run-firmware.ps1 para los perfiles técnicos.
param(
    [string]$Qemu,
    [switch]$SoloTerminal,
    [switch]$Comprobar
)
$ErrorActionPreference='Stop'
$options=@{Monitor=$true;Headless=[bool]$SoloTerminal;Check=[bool]$Comprobar}
if($Qemu){$options.Qemu=$Qemu}
& "$PSScriptRoot/run-firmware.ps1" @options
