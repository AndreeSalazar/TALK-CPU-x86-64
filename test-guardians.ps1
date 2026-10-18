# Pruebas de reglas con copias de metadatos. No modifica fuentes ni ROM.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Faggin scaling\guardians\check-layout.ps1"
$layoutPath = "$PSScriptRoot\Faggin scaling\guardians\layout.psd1"
$sourceRoot = "$PSScriptRoot\Faggin scaling"
$baselineSources = @('16-bit\entry.hex','16-bit\halt.hex','16-bit\message.hex','16-bit\reset.hex')
$tests = @(
    @{Name='Distribucion valida';Allowed=$true;Guard='Layout';Level='GREEN';Mutate=$null},
    @{Name='Cruce de carriles ROM';Allowed=$false;Guard='Overlap';Level='RED';Mutate={param($layout) $layout.Sources['16-bit\halt.hex'].Start=0x10}},
    @{Name='Cruce de reservas RAM';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'IDT').Start=0x7000}},
    @{Name='Bytes exceden su presupuesto';Allowed=$false;Guard='Encoding';Level='RED';Mutate={param($layout) $layout.Sources['16-bit\message.hex'].End=0x90}},
    @{Name='Fuente sin propietario';Allowed=$false;Guard='Ownership';Level='RED';Extra='README.md';Mutate=$null},
    @{Name='Reserva desalineada';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'TSS').Start=0x7001}},
    @{Name='Imagen incompatible';Allowed=$false;Guard='Profile';Level='RED';Mutate={param($layout) $layout.RomBytes=0x8000}},
    @{Name='Margen reducido avisa sin bloquear';Allowed=$true;Guard='Margin';Level='YELLOW';Mutate={param($layout) $layout.Sources['16-bit\message.hex'].End=0xA0}}
)
$results = @()
foreach ($test in $tests) {
    $layout = Import-PowerShellDataFile $layoutPath
    if ($test.Mutate) { & ($test.Mutate) $layout }
    $sources = $baselineSources
    if ($test.Extra) { $sources += $test.Extra }
    $report = Test-FirmwareLayout -Layout $layout -Sources $sources -SourceRoot $sourceRoot
    $matching = @($report.Findings | Where-Object { $_.Guard -eq $test.Guard -and $_.Level -eq $test.Level })
    $passed = $report.Allowed -eq $test.Allowed -and $matching.Count -gt 0
    $results += [pscustomobject]@{Name=$test.Name;Passed=$passed;Expected=$test.Level;Observed=$report.Status}
    if ($passed) { Write-Host "GREEN [GuardianTest] $($test.Name): regla comprobada ($($test.Level))." -ForegroundColor Green }
    else { Write-Host "RED [GuardianTest] $($test.Name): resultado inesperado." -ForegroundColor Red }
}
$passedCount = @($results | Where-Object Passed).Count
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'build') | Out-Null
[ordered]@{Passed=$passedCount;Total=$results.Count;Cases=$results} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build\guardian-test-results.json') -Encoding utf8
if ($passedCount -ne $results.Count) { throw "RED: solo $passedCount de $($results.Count) reglas comprobadas." }
