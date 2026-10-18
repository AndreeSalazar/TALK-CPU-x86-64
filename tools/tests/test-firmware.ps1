# Una VM por caso. No usa discos ni modifica el firmware del anfitrion.
param([string]$Qemu)

$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
$cases = @(
    @{ Name='Consola propia de 64 bits'; Profile='faggin-64-monitor'; Options=@{Monitor=$true} },
    @{ Name='Arranque hasta 16 bits'; Profile='faggin-16'; Options=@{Stage='16'} },
    @{ Name='Arranque hasta 32 bits'; Profile='faggin-32'; Options=@{Stage='32'} },
    @{ Name='Arranque hasta 64 bits'; Profile='faggin-64'; Options=@{Stage='64'} },
    @{ Name='RAM: 32 rondas'; Profile='faggin-64-stress'; Options=@{Stress=$true} },
    @{ Name='RAM: corrupcion esperada'; Profile='faggin-64-stress-fault'; Options=@{Stress=$true;InjectFault=$true} }
)
foreach ($faultName in @('divide','invalid','page','general','double','write','execute','guard','stack')) {
    $cases += @{ Name="Excepcion esperada: $faultName"; Profile="faggin-64-exception-$faultName"; Options=@{Exception=$faultName} }
}

Push-Location $ProjectRoot
try {
    & "$ProjectRoot\tools/tests/test-guardians.ps1"
    $guardianTests = Get-Content 'build\guardian-test-results.json' -Raw | ConvertFrom-Json
    $results = @()
    foreach ($case in $cases) {
        Write-Host "`n--- $($case.Name) ---"
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $passed = $false
        $failure = $null
        try {
            $arguments = @{Check=$true}
            if ($Qemu) { $arguments.Qemu = $Qemu }
            foreach ($key in $case.Options.Keys) { $arguments[$key] = $case.Options[$key] }
            & "$ProjectRoot\tools/qemu/run-firmware.ps1" @arguments
            $traceName=if ($case.Options.Monitor) { "$($case.Profile)-check" } else { $case.Profile }
            $trace = Get-Content -LiteralPath "build\$traceName-instructions.log" -Raw
            if ($trace -match 'Triple fault') { throw 'Triple fallo de CPU.' }
            if (-not $case.Options.ContainsKey('Exception') -and $trace -match 'check_exception') {
                throw 'Una prueba normal produjo una excepcion inesperada.'
            }
            if ($case.Profile -eq 'faggin-64') {
                if ($trace -notmatch 'CS64' -or $trace -notmatch 'EFER=0000000000000d00' -or
                    $trace -notmatch 'IDT=\s+0000000000008000 00000fff' -or
                    $trace -notmatch 'TR =0020 0000000000007000 00000067 00008[9b]00') {
                    throw 'No se confirmaron long mode, IDT y TSS activos en la CPU.'
                }
            }
            $map = Get-Content -LiteralPath "build\$($case.Profile)-map.json" -Raw | ConvertFrom-Json
            if ($map.RomBytes -ne 65536 -or $map.AuthoredBytes -le 0 -or
                $map.AuthoredBytes + $map.PaddingBytes -ne $map.RomBytes) {
                throw 'Informe de tamano inconsistente.'
            }
            $guardians = Get-Content -LiteralPath "build\$($case.Profile)-guardians.json" -Raw | ConvertFrom-Json
            if (-not $guardians.Allowed -or $guardians.Status -eq 'RED') { throw 'Los guardianes no autorizaron esta ROM.' }
            $passed = $true
        }
        catch {
            $failure = $_.Exception.Message
            Write-Host "FALLO: $failure"
        }
        $results += [pscustomobject]@{
            Name=$case.Name; Profile=$case.Profile; Passed=$passed
            Seconds=[Math]::Round($timer.Elapsed.TotalSeconds, 3); Error=$failure
        }
    }
    $passedCount = @($results | Where-Object Passed).Count
    & "$ProjectRoot\tools/tests/test-programs.ps1" -Qemu $Qemu
    $programTests=Get-Content 'build\program-test-results.json' -Raw | ConvertFrom-Json
    & "$ProjectRoot\tools/tests/test-screen.ps1" -Qemu $Qemu
    $screenTests=Get-Content 'build\screen-test-results.json' -Raw | ConvertFrom-Json
    & "$ProjectRoot\tools/tests/test-screen.ps1" -Qemu $Qemu -InjectCursorFault
    $cursorTests=Get-Content 'build\screen-cursor-test-results.json' -Raw | ConvertFrom-Json
    & "$ProjectRoot\tools/tests/test-storage.ps1" -Qemu $Qemu
    $storageTests=Get-Content 'build\storage-test-results.json' -Raw | ConvertFrom-Json
    & "$ProjectRoot\tools/tests/test-gpt.ps1" -Qemu $Qemu
    $gptTests=Get-Content 'build\gpt-test-results.json' -Raw | ConvertFrom-Json
    & "$ProjectRoot\tools/tests/test-arranque.ps1" -Qemu $Qemu
    $bootTests=Get-Content 'build\boot-test-results.json' -Raw | ConvertFrom-Json
    [ordered]@{
        Platform='QEMU pc / qemu64 / TCG / 16 MiB / 1 CPU'
        Passed=$passedCount; Total=$results.Count; Cases=$results
        GuardianTests=@{Passed=$guardianTests.Passed;Total=$guardianTests.Total}
        ProgramTests=@{Passed=$programTests.Passed;Total=$programTests.Total}
        ScreenTests=@{Passed=($screenTests.Passed+$cursorTests.Passed);Total=($screenTests.Total+$cursorTests.Total)}
        StorageTests=@{Passed=$storageTests.Passed;Total=$storageTests.Total}
        GPTTests=@{Passed=$gptTests.Passed;Total=$gptTests.Total}
        BootTests=@{Passed=$bootTests.Passed;Total=$bootTests.Total}
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath 'build\test-results.json' -Encoding utf8
    Write-Host "`nResultado: $passedCount de $($results.Count) pruebas aprobadas."
    Write-Host "Guardianes de construccion: $($guardianTests.Passed) de $($guardianTests.Total) reglas comprobadas."
    Write-Host "Paquetes invalidos: $($programTests.Passed) de $($programTests.Total) rechazos comprobados."
    Write-Host 'Pantalla y teclado: recorrido normal y recuperacion de cursor comprobados.'
    Write-Host "Disco FAT32: $($storageTests.Passed) de $($storageTests.Total) recorridos comprobados."
    Write-Host "GPT y clusters: $($gptTests.Passed) de $($gptTests.Total). Arranque y capturas: $($bootTests.Passed) de $($bootTests.Total)."
    Write-Host 'Informe: build\test-results.json'
    if ($passedCount -ne $results.Count) { throw 'La bateria de pruebas no esta completa: revisar el informe.' }
}
finally { Pop-Location }
