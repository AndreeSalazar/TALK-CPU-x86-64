# Analisis offline de la referencia MSI. No invoca ninguna herramienta de grabacion.
param([switch]$Descargar,[string]$Python)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    if(-not $Python){
        $command=Get-Command python -ErrorAction SilentlyContinue
        $Python=if($command){$command.Source}else{Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
    }
    if(-not(Test-Path -LiteralPath $Python)){throw 'Indica una instalacion Python 3 con -Python.'}
    $archive='build/analisis-msi/7C52v2C.zip'
    New-Item -ItemType Directory -Force 'build/analisis-msi' | Out-Null
    if($Descargar){
        Invoke-WebRequest -Uri 'https://download.msi.com/bos_exe/mb/7C52v2C.zip' -OutFile $archive
    }
    if(-not(Test-Path -LiteralPath $archive)){throw 'Falta el paquete local. Usa -Descargar para obtener la referencia de MSI.'}
    # Huella observada el 18-10-2026; fija nuestra referencia, no es una firma MSI.
    $expected='FCE8FAAC05AA2E73752E946DA7A4171CB4D9DEF4B3AB561D835286129DC5B961'
    if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -cne $expected){throw 'El paquete no coincide con la referencia analizada. Revisar origen y version antes de continuar.'}
    & $Python "$PSScriptRoot/analizar-firmware-msi.py" $archive --output 'build/analisis-msi/inventario.json'
    if($LASTEXITCODE -ne 0){throw 'Fallo el inventario de firmware.'}
    & $Python "$PSScriptRoot/test-analisis-msi.py" $archive
    if($LASTEXITCODE -ne 0){throw 'Fallo la comprobacion del analizador.'}
    & $Python "$PSScriptRoot/trazar-inicio-msi.py" $archive --output 'build/analisis-msi/trazado.json'
    if($LASTEXITCODE -ne 0){throw 'Fallo el trazado AMD/PEI.'}
    & $Python "$PSScriptRoot/test-trazado-msi.py" $archive
    if($LASTEXITCODE -ne 0){throw 'Fallo una comprobacion del trazado.'}
    Write-Host 'Informe: build/analisis-msi/inventario.json. No se ha generado una imagen modificada.'
}finally{Pop-Location}
