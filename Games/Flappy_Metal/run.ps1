param([switch]$Check,[string]$Python,[string]$Qemu)
$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot)
if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
if(-not $Qemu){$Qemu=Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
Push-Location $project
try {
    & "$project/tools/build/construir-puente.ps1" *> 'build/Flappy_Metal-bridge.log'
    $cases=if($Check){@('normal','outside','empty')}else{@('normal')}
    foreach($case in $cases){
        & $Python "$PSScriptRoot/build.py" --case $case
        if($LASTEXITCODE -ne 0){throw 'Scene packaging failed.'}
        & "$project/tools/build/crear-disco.ps1" -GPT -Programa "build/Flappy_Metal/scene-$case.x86" *> 'build/Flappy_Metal/image.log'
        & $Python "$project/tools/build/preparar-imagen-puente.py" --caso normal
        if($LASTEXITCODE -ne 0){throw 'Scene virtual image preparation failed.'}
        if($Check){
            & $Python "$PSScriptRoot/test_scene.py" --case $case --qemu $Qemu
            if($LASTEXITCODE -ne 0){throw "Scene check failed: $case"}
        }
    }
    if($Check){
        # Leave the runnable virtual image in the normal scene state after fault tests.
        & "$project/tools/build/crear-disco.ps1" -GPT -Programa build/Flappy_Metal/scene-normal.x86 *> 'build/Flappy_Metal/image.log'
        & $Python "$project/tools/build/preparar-imagen-puente.py" --caso normal
        if($LASTEXITCODE -ne 0){throw 'Normal scene image restoration failed.'}
        Write-Host 'GREEN [SCENE] All scene checks passed. Static preview only; no keyboard or physics yet.'
    }else{
        $share=Join-Path (Split-Path $Qemu) 'share'
        Copy-Item (Join-Path $share 'edk2-i386-vars.fd') 'build/Flappy_Metal/live-vars.fd' -Force
        & $Qemu -name 'Flappy Metal - static scene' -machine pc -cpu qemu64 -accel tcg -m 256M -smp 1 `
            -drive "if=pflash,format=raw,unit=0,readonly=on,file=$share/edk2-x86_64-code.fd" `
            -drive 'if=pflash,format=raw,unit=1,file=build/Flappy_Metal/live-vars.fd' `
            -drive 'file=build/puente-normal.img,format=raw,if=ide,snapshot=on' -vga std -display gtk -serial none -monitor none -no-reboot
        if($LASTEXITCODE -ne 0){throw 'QEMU scene process failed.'}
    }
}finally{Pop-Location}
