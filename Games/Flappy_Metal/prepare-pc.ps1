param([switch]$Check,[string]$Python,[string]$Qemu)
$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot)
if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
if(-not $Qemu){$Qemu=Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
Push-Location $project
try {
    New-Item -ItemType Directory -Force build/Flappy_Metal | Out-Null
    & "$project/tools/build/construir-puente.ps1" *> build/Flappy_Metal/preview-build.log
    & $Python "$PSScriptRoot/build.py"
    if($LASTEXITCODE -ne 0){throw 'Static scene build failed.'}
    & $Python "$PSScriptRoot/prepare_pc.py"
    if($LASTEXITCODE -ne 0){throw 'PC preview package preparation failed.'}
    if($Check){
        & "$project/tools/build/crear-disco.ps1" -GPT -Programa build/Flappy_Metal/PC_PREVIEW/METAL/FLAPPY.X86 *> build/Flappy_Metal/preview-image.log
        & $Python "$project/tools/build/preparar-imagen-puente.py" --profile flappy-preview
        if($LASTEXITCODE -ne 0){throw 'Preview virtual image preparation failed.'}
        & $Python "$PSScriptRoot/test_scene.py" --case normal --qemu $Qemu
        if($LASTEXITCODE -ne 0){throw 'Separate preview EFI/path failed QEMU verification.'}
        Copy-Item build/Flappy_Metal/test-normal.json build/Flappy_Metal/pc-preview-qemu.json -Force
        Copy-Item build/Flappy_Metal/scene-normal.png build/Flappy_Metal/pc-preview-qemu.png -Force
    }
    Write-Host 'GREEN [PC-PREVIEW] Static only; no animation or keyboard. Package: build/Flappy_Metal/PC_PREVIEW.'
    Write-Host 'Preparing/checking this package does not copy to the physical SSD or change firmware entries.'
}finally{Pop-Location}
