param([switch]$Check,[switch]$Static,[string]$Python,[string]$Qemu)
$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot)
if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
if(-not $Qemu){$Qemu=Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
Push-Location $project
try {
    & "$project/tools/build/construir-puente.ps1" *> 'build/Flappy_Metal-bridge.log'
    if($Check){
        & $Python "$PSScriptRoot/test_builder.py"
        if($LASTEXITCODE -ne 0){throw 'Game branch-operand checks failed.'}
    }
    $cases=if($Check){@('normal','outside','empty')}elseif($Static){@('normal')}else{@()}
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
    if(-not $Static -or $Check){
        $gameCases=if($Check){@('normal','ceiling','pipe','wrap','scorecap','clip','timerfault','keyboardfault')}else{@('normal')}
        foreach($gameCase in $gameCases){
            & $Python "$PSScriptRoot/build.py" --play --game-case $gameCase
            if($LASTEXITCODE -ne 0){throw 'Game packaging failed.'}
            $packet=if($gameCase -eq 'normal'){'game.x86'}else{"game-$gameCase.x86"}
            & "$project/tools/build/crear-disco.ps1" -GPT -Programa "build/Flappy_Metal/$packet" *> 'build/Flappy_Metal/game-image.log'
            & $Python "$project/tools/build/preparar-imagen-puente.py" --caso normal
            if($LASTEXITCODE -ne 0){throw 'Game virtual image preparation failed.'}
            if($Check){
                & $Python "$PSScriptRoot/test_game.py" --fixture $gameCase --qemu $Qemu
                if($LASTEXITCODE -ne 0){throw "Game check failed: $gameCase"}
            }
        }
    }
    if($Check){
        # Leave the normal playable virtual image after all injected test packets.
        & "$project/tools/build/crear-disco.ps1" -GPT -Programa build/Flappy_Metal/game.x86 *> 'build/Flappy_Metal/game-image.log'
        & $Python "$project/tools/build/preparar-imagen-puente.py" --caso normal
        if($LASTEXITCODE -ne 0){throw 'Normal game image restoration failed.'}
        Write-Host 'GREEN [GAME] Scene checks, interactive gameplay and injected guard checks passed. No physical installation.'
    }else{
        $share=Join-Path (Split-Path $Qemu) 'share'
        Copy-Item (Join-Path $share 'edk2-i386-vars.fd') 'build/Flappy_Metal/live-vars.fd' -Force
        & $Qemu -name 'Flappy Metal - SPACE flap, ENTER restart, ESC stop' -machine pc -cpu qemu64 -accel tcg -m 256M -smp 1 `
            -drive "if=pflash,format=raw,unit=0,readonly=on,file=$share/edk2-x86_64-code.fd" `
            -drive 'if=pflash,format=raw,unit=1,file=build/Flappy_Metal/live-vars.fd' `
            -drive 'file=build/puente-normal.img,format=raw,if=ide,snapshot=on' -vga std -display gtk -serial none -monitor none -no-reboot
        if($LASTEXITCODE -ne 0){throw 'QEMU scene process failed.'}
    }
}finally{Pop-Location}
