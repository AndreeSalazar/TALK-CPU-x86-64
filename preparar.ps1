# Paquete reproducible de archivos para QEMU. Solo escribe dentro de build/.
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor
    $destination=Join-Path $PSScriptRoot 'build/Orquestador_Metal'
    New-Item -ItemType Directory -Force "$destination/programas" | Out-Null
    $files=@(
        @{Source='faggin-64-monitor.rom';Target='firmware.rom'},
        @{Source='hola.x86';Target='programas/hola.x86'},
        @{Source='eco.x86';Target='programas/eco.x86'}
    )
    $entries=@()
    foreach($file in $files){
        $source=Join-Path "$PSScriptRoot/build" $file.Source
        $target=Join-Path $destination $file.Target
        Copy-Item -LiteralPath $source -Destination $target -Force
        $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $targetHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if($sourceHash -cne $targetHash){throw "La copia no coincide: $($file.Target)"}
        $entries += [ordered]@{Ruta=$file.Target;Bytes=(Get-Item -LiteralPath $target).Length;SHA256=$targetHash}
    }
    [ordered]@{
        Formato=1;Nombre='Orquestador del Metal';Arquitectura='x86-64'
        Plataforma='QEMU pc / qemu64 / 16 MiB / 1 CPU'
        Entrada='RESET';Uso='ROM de firmware para QEMU; no es una imagen de disco'
        Archivos=$entries
    } | ConvertTo-Json -Depth 4 | Set-Content "$destination/manifiesto.json" -Encoding utf8
    @'
ORQUESTADOR DEL METAL

firmware.rom: firmware propio desde RESET para la maquina pc de QEMU.
programas/: paquetes FAGRAW64 exportados; tambien estan incluidos en la ROM.
manifiesto.json: longitudes y huellas SHA-256 de estos tres archivos.

Desde la raiz del proyecto: ./iniciar.ps1

Este paquete no es un instalador ni una imagen de disco. No contiene una entrada
.efi ni inicializa la placa MSI. Copiarlo a un disco no hace que la placa lo cargue.
El descubrimiento propio de programas externos sigue pendiente de implementar.
'@ | Set-Content "$destination/LEEME.txt" -Encoding utf8
    Write-Host "Paquete preparado: $destination"
    Write-Host 'ROM y programas copiados con huellas SHA-256 verificadas.'
}
finally {Pop-Location}
