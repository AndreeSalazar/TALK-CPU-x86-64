param([switch]$Comprobar,[string]$Qemu,[string]$Python)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    if(-not $Qemu){$Qemu=Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
    if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
    if(-not(Test-Path $Qemu) -or -not(Test-Path $Python)){throw 'Indica -Qemu y -Python con las rutas instaladas.'}
    & "$PSScriptRoot/construir-puente.ps1"
    & "$PSScriptRoot/crear-disco.ps1" -GPT -Programa build/Puente_Metal/METAL/INICIO.X86
    $cases=if($Comprobar){@('normal','firma','suma','ausente','excesivo','entrada','salida')}else{@('normal')}
    foreach($case in $cases){
        & $Python "$PSScriptRoot/preparar-imagen-puente.py" --caso $case
        if($LASTEXITCODE -ne 0){throw "Fallo la imagen virtual: $case"}
    }
    if($Comprobar){
        & $Python -u "$PSScriptRoot/test-puente.py" --qemu $Qemu --casos @cases
        if($LASTEXITCODE -ne 0){throw 'Fallo una comprobacion del puente.'}
    }else{
        $share=Join-Path (Split-Path $Qemu) 'share'
        $code=Join-Path $share 'edk2-x86_64-code.fd'
        $varsSource=Join-Path $share 'edk2-i386-vars.fd'
        Copy-Item -LiteralPath $varsSource -Destination build/puente-live-vars.fd -Force
        & $Qemu -name 'Orquestador del Metal - puente UEFI' -machine pc -cpu qemu64 -accel tcg -m 256M -smp 1 `
            -drive "if=pflash,format=raw,unit=0,readonly=on,file=$code" `
            -drive 'if=pflash,format=raw,unit=1,file=build/puente-live-vars.fd' `
            -drive 'file=build/puente-normal.img,format=raw,if=ide,snapshot=on' `
            -vga std -display gtk -serial stdio -monitor none -no-reboot
        if($LASTEXITCODE -ne 0){throw "QEMU termino con codigo $LASTEXITCODE"}
    }
}finally{Pop-Location}
