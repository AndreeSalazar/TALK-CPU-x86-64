param(
    [string]$Qemu,
    [switch]$Check,
    [ValidateSet('16', '32', '64')]
    [string]$Stage = '64',
    [switch]$Stress,
    [switch]$InjectFault,
    [ValidateSet('None','divide','invalid','page','general','double','write','execute','guard','stack')]
    [string]$Exception = 'None'
)

$ErrorActionPreference = "Stop"
if ($Stress -and $Stage -ne '64') { throw '-Stress requiere -Stage 64.' }
if ($InjectFault -and -not $Stress) { throw '-InjectFault requiere -Stress.' }
if ($Exception -ne 'None' -and ($Stage -ne '64' -or $Stress)) {
    throw '-Exception requiere -Stage 64 y no se combina con -Stress.'
}
$buildName = "faggin-$Stage"
if ($Stress) { $buildName += '-stress' }
if ($InjectFault) { $buildName += '-fault' }
if ($Exception -ne 'None') { $buildName += "-exception-$Exception" }
if (-not $Qemu) {
    $Qemu = "qemu-system-x86_64.exe"
    if (-not (Get-Command $Qemu -ErrorAction SilentlyContinue)) {
        $installedQemu = Join-Path $env:ProgramFiles "qemu\qemu-system-x86_64.exe"
        if (Test-Path -LiteralPath $installedQemu) { $Qemu = $installedQemu }
    }
}
$qemuCommand = Get-Command $Qemu -ErrorAction SilentlyContinue
if (-not $qemuCommand) {
    throw "No se encontro QEMU. Instala QEMU o usa -Qemu 'C:\ruta\qemu-system-x86_64.exe'."
}

Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot\Faggin scaling\build-firmware.ps1" -Stage $Stage -Stress:$Stress -InjectFault:$InjectFault -Exception $Exception
    $romPath = "build/$buildName.rom"
    if ((Get-Item $romPath).Length -ne 65536) {
        throw "La ROM debe medir exactamente 65536 bytes."
    }
    if ($Check) {
        $debugLogRelative = "build/$buildName-debug.log"
        $traceLogRelative = "build/$buildName-instructions.log"
        $errorLog = Join-Path $PSScriptRoot "build\$buildName-error.log"
        $debugLog = Join-Path $PSScriptRoot $debugLogRelative
        $expectedMessage = "Faggin scaling: 16 bits OK`r`n"
        if ($Stage -ne '16') { $expectedMessage += "Faggin scaling: 32 bits OK`r`n" }
        if ($Stage -eq '64') { $expectedMessage += "Faggin scaling: 64 bits OK`r`nGREEN [CPU] guardians active`r`nGREEN [Memory] bounded allocator OK`r`n" }
        if ($Stress) {
            if ($InjectFault) { $expectedMessage += "`r`nRED [RAM] Faggin scaling: RAM FAIL`r`n" }
            else { $expectedMessage += ('.' * 32) + "`r`nGREEN [RAM] Faggin scaling: RAM 1 MiB x 32 OK`r`n" }
        }
        $haltAddress = @{ '16'='000f0024'; '32'='000f0225'; '64'='000f22e0' }[$Stage]
        if ($Stress) { $haltAddress = '000f06d8' }
        if ($Exception -ne 'None') {
            $exceptionCases = Import-PowerShellDataFile "$PSScriptRoot\Faggin scaling\64-bit\diagnostics\tests\cases.psd1"
            $faultCase = $exceptionCases[$Exception]
            $expectedMessage += ('RED [CPU] Faggin scaling: CPU fault vector={0:X16}' -f [long]$faultCase.Vector)
            $expectedMessage += ("`r`nrip={0:X16}" -f [long]$faultCase.Rip)
            $expectedMessage += ("`r`nerror={0:X16}" -f [long]$faultCase.Error)
            $expectedMessage += ("`r`ncr2={0:X16}" -f [long]$faultCase.Cr2)
            $expectedMessage += ("`r`nframe={0:X16}" -f [long]$faultCase.Frame)
            $expectedMessage += "`r`ncause=$($faultCase.Cause)`r`n"
            $haltAddress = '000f1597'
        }
        # No registrar cada vuelta de los bucles de RAM: serian millones de bloques.
        $traceOptions = 'in_asm,cpu,int'
        if ($Stress) { $traceOptions = 'in_asm,int' }
        [IO.File]::WriteAllText($debugLog, "")
        $qemuProcess = $null
        try {
            $qemuProcess = Start-Process -FilePath $qemuCommand.Source -WindowStyle Hidden -PassThru `
                -WorkingDirectory $PSScriptRoot -ArgumentList @(
                    '-machine', 'pc', '-cpu', 'qemu64', '-accel', 'tcg', '-m', '16M', '-smp', '1',
                    '-bios', $romPath, '-nodefaults', '-display', 'none',
                    '-serial', 'none', '-monitor', 'none',
                    '-chardev', "file,id=talkdebug,path=$debugLogRelative",
                    '-device', 'isa-debugcon,iobase=0xe9,chardev=talkdebug', '-no-reboot',
                    '-d', $traceOptions, '-D', $traceLogRelative
                ) -RedirectStandardError $errorLog
            $checkTimer = [Diagnostics.Stopwatch]::StartNew()
            do {
                if ($qemuProcess.HasExited) {
                    $details = Get-Content -LiteralPath $errorLog -Raw
                    throw "QEMU termino antes de completar la prueba: $details"
                }
                $logStream = [IO.File]::Open($debugLog, [IO.FileMode]::Open,
                    [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                $logReader = [IO.StreamReader]::new($logStream)
                try { $message = $logReader.ReadToEnd() }
                finally { $logReader.Dispose() }
                $atExpectedHalt = $false
                if ($message -eq $expectedMessage) {
                    $traceStream = [IO.File]::Open((Join-Path $PSScriptRoot $traceLogRelative),
                        [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                    $traceReader = [IO.StreamReader]::new($traceStream)
                    try { $traceText = $traceReader.ReadToEnd() }
                    finally { $traceReader.Dispose() }
                    if ($traceText -match 'Triple fault') { throw 'La CPU sufrio un triple fallo.' }
                    $atExpectedHalt = $traceText -match "0x${haltAddress}:\s+f4\s+hlt"
                }
                if ($atExpectedHalt) {
                    if ($Exception -ne 'None') { Write-Host "OK: excepcion $Exception informada con vector, RIP, error, CR2 y pila correctos." }
                    elseif ($InjectFault) { Write-Host 'OK: el firmware detecto la corrupcion provocada en RAM.' }
                    elseif ($Stress) { Write-Host 'OK: 32 rondas de RAM completadas por el firmware de 64 bits.' }
                    else { Write-Host "OK: QEMU arranco desde RESET y completo en orden las etapas hasta $Stage bits." }
                    Write-Host $message -NoNewline
                    Write-Host "Registro: $debugLog"
                    return
                }
                if (-not $InjectFault -and $message.Contains('RAM FAIL')) {
                    throw "El firmware detecto un error de RAM. Revisa $debugLogRelative."
                }
                if ($message.Contains('allocator self-test FAIL')) { throw "RED: el servicio de memoria no paso su autoprueba. $message" }
                if ($Exception -eq 'None' -and $message.Contains('CPU fault vector=')) {
                    throw "El firmware informo un fallo de CPU: $message"
                }
                Start-Sleep -Milliseconds 100
            } while ($checkTimer.Elapsed.TotalSeconds -lt 30)
            throw "No se recibio el resultado esperado en 30 segundos. Revisa $debugLogRelative y $traceLogRelative."
        }
        finally {
            if ($qemuProcess -and -not $qemuProcess.HasExited) {
                $qemuProcess.Kill()
                $qemuProcess.WaitForExit()
            }
        }
    }
    Write-Host "Faggin scaling en QEMU: desde RESET hasta $Stage bits. Ctrl+C para salir."
    if ($Exception -ne 'None') { Write-Host "Prueba negativa: excepcion $Exception provocada dentro de la VM." }
    elseif ($InjectFault) { Write-Host 'Prueba negativa: RAM FAIL es el resultado esperado.' }
    elseif ($Stress) { Write-Host 'Prueba RAM: 1 MiB, 32 rondas. Cada punto confirma una ronda completa.' }
    & $qemuCommand.Source -machine pc -cpu qemu64 -accel tcg -m 16M -smp 1 `
        -bios $romPath -nodefaults -display none `
        -serial none -monitor none -chardev stdio,id=talkdebug `
        -device isa-debugcon,iobase=0xe9,chardev=talkdebug -no-reboot
    if ($LASTEXITCODE -ne 0) { throw "QEMU termino con codigo $LASTEXITCODE." }
}
finally {
    Pop-Location
}
