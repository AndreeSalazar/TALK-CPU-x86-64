# Entrada en español. Conserva tools/qemu/run-firmware.ps1 para los perfiles técnicos.
param(
    [string]$Qemu,
    [switch]$SoloTerminal,
    [switch]$Disco,
    [switch]$Manual,
    [switch]$Comprobar
)
$ErrorActionPreference='Stop'
$options=@{Monitor=$true;Headless=[bool]$SoloTerminal;Check=[bool]$Comprobar;Disk=[bool]$Disco;AutoBoot=($Disco -and -not $Manual)}
if($Qemu){$options.Qemu=$Qemu}
& "$PSScriptRoot/tools/qemu/run-firmware.ps1" @options
