param([string]$Source,[string]$Python,[string]$Compiler)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if(-not $Source){$Source=Join-Path $PSScriptRoot 'examples/hello.casm'}
if(-not $Python){$Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
$sourcePath=(Resolve-Path -LiteralPath $Source).Path
& "$PSScriptRoot/build.ps1" -Compiler $Compiler
$run=Join-Path $root ('build/CASM/run-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $run | Out-Null
# Freeze the exact source passed to both controls. Failed runs have no published package.
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $run 'source.casm')
& (Join-Path $root 'build/CASM/host/casmc.exe') (Join-Path $run 'source.casm') (Join-Path $run 'program.hex') (Join-Path $run 'program.ir.json')
if($LASTEXITCODE -ne 0){throw "RED [COMPILE] Source rejected. No executable package published. Run: $run"}
& $Python "$PSScriptRoot/verify.py" (Join-Path $run 'source.casm') (Join-Path $run 'program.hex') (Join-Path $run 'program.ir.json') --packet (Join-Path $run 'INICIO.X86') --report (Join-Path $run 'verified.json')
if($LASTEXITCODE -ne 0){throw "RED [COMPILE] Emission rejected. Run: $run"}
Write-Host "GREEN [READY] Verified output: $run"
Write-Host 'No physical SSD, firmware entry or installed payload was changed.'
