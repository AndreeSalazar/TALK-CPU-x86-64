param([switch]$Qemu,[string]$Python,[string]$Compiler)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
Push-Location $root
try {
    & "$PSScriptRoot/build.ps1" -Compiler $Compiler
    & $Python "$PSScriptRoot/test.py"
    if($LASTEXITCODE -ne 0){throw 'CASM host tests failed.'}
    if($Qemu){
        & "$root/tools/build/construir-puente.ps1"
        if((Get-FileHash 'build/CASM/hello.x86').Hash -ne (Get-FileHash 'build/Puente_Metal/METAL/INICIO.X86').Hash){throw 'CASM hello differs from the golden bridge packet.'}
        & "$root/tools/build/crear-disco.ps1" -GPT -Programa build/CASM/hello.x86
        & $Python "$root/tools/build/preparar-imagen-puente.py" --caso normal
        if($LASTEXITCODE -ne 0){throw 'CASM virtual image preparation failed.'}
        & $Python -u "$root/tools/tests/test-puente.py" --casos normal
        if($LASTEXITCODE -ne 0){throw 'CASM payload QEMU test failed.'}
        Copy-Item build/puente-test-results.json build/CASM/qemu-test-results.json -Force
        Copy-Item build/puente-normal.png build/CASM/qemu-hello.png -Force
        Write-Host 'GREEN [QEMU] CASM-generated packet executed after ExitBootServices.'
    }
}finally{Pop-Location}
