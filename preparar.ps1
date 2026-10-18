# Paquete reproducible de archivos para QEMU. Solo escribe dentro de build/.
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor -AutoBoot
    & "$PSScriptRoot/tools/build/crear-disco.ps1" -GPT -SectoresPorCluster 8
    $destination=Join-Path $PSScriptRoot 'build/Orquestador_Metal'
    New-Item -ItemType Directory -Force "$destination/programas" | Out-Null
    $files=@(
        @{Source='faggin-64-monitor.rom';Target='firmware.rom'},
        @{Source='hola.x86';Target='programas/hola.x86'},
        @{Source='eco.x86';Target='programas/eco.x86'},
        @{Source='disco-inicio.x86';Target='programas/inicio.x86'},
        @{Source='disco-fat32-gpt-c8.img';Target='almacenamiento.img'}
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
        Formato=1;Version='1.0-QEMU';Nombre='Orquestador del Metal';Arquitectura='x86-64'
        Plataforma='QEMU pc / qemu64 / 16 MiB / 1 CPU'
        Entrada='RESET';ArranqueAutomatico=$true;Almacenamiento='GPT / FAT32 / cluster 4096 bytes'
        Uso='QEMU pc: firmware.rom mas almacenamiento.img; no es firmware para la placa fisica'
        Archivos=$entries
    } | ConvertTo-Json -Depth 4 | Set-Content "$destination/manifiesto.json" -Encoding utf8
    @'
ORQUESTADOR DEL METAL

firmware.rom: firmware propio desde RESET para la maquina pc de QEMU.
almacenamiento.img: disco virtual GPT/FAT32 con METAL/INICIO.X86.
programas/: ejemplos FAGRAW64 exportados; inicio.x86 es el programa externo.
manifiesto.json: longitudes y huellas SHA-256.

Dentro de este paquete: ./INICIAR.ps1
Desde la raiz del proyecto: ./iniciar.ps1 -Disco

El firmware busca el programa al arrancar. Si falla o el programa retorna,
queda disponible el monitor. e abre eco, Escape retorna y q detiene la CPU.
No contiene una entrada .efi ni inicializa la placa MSI. Es un paquete para QEMU.
'@ | Set-Content "$destination/LEEME.txt" -Encoding utf8
    @'
param([string]$Qemu)
$ErrorActionPreference='Stop'
if(-not $Qemu){
    $cmd=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
    $Qemu=if($cmd){$cmd.Source}else{Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
}
Push-Location $PSScriptRoot
try {
    & $Qemu -name 'Orquestador del Metal' -machine pc -cpu qemu64 -accel tcg -m 16M -smp 1 `
        -bios firmware.rom -nodefaults -device VGA,addr=2 -display gtk -serial stdio -monitor none `
        -drive file=almacenamiento.img,format=raw,if=none,id=metal,snapshot=on `
        -device ide-hd,drive=metal,bus=ide.0,unit=0 `
        -chardev file,id=debug,path=diagnostico.log -device isa-debugcon,iobase=0xe9,chardev=debug -no-reboot
    if($LASTEXITCODE -ne 0){throw "QEMU termino con codigo $LASTEXITCODE"}
}finally{Pop-Location}
'@ | Set-Content "$destination/INICIAR.ps1" -Encoding utf8
    Write-Host "Paquete preparado: $destination"
    Write-Host 'ROM y programas copiados con huellas SHA-256 verificadas.'
}
finally {Pop-Location}
