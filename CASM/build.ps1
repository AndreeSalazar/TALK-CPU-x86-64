param([string]$Compiler,[string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if(-not $Compiler){$Compiler=Join-Path $env:ProgramFiles 'LLVM/bin/clang.exe'}
if(-not(Test-Path -LiteralPath $Compiler)){throw 'C bootstrap compiler not found. Supply -Compiler with a Clang-compatible host compiler.'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'build/CASM/host'}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$output=Join-Path $OutputDirectory 'casmc.exe'
$sources=@('main.c','frontend.c','emitter.c') | ForEach-Object {Join-Path $PSScriptRoot "src/$_"}
# Use the ISO C file API; MSVC's optional *_s API is not required by this host tool.
& $Compiler -std=c11 -D_CRT_SECURE_NO_WARNINGS -Wall -Wextra -Werror -pedantic -O2 @sources -o $output
if($LASTEXITCODE -ne 0){throw 'CASM host compiler build failed.'}
Write-Host "GREEN [BOOTSTRAP] Host compiler built: $output"
