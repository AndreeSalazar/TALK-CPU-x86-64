# Une las etapas elegidas sin ensamblar ni generar instrucciones.
# Cada .hex declara sus offsets de ROM y comprueba sus limites.
param(
    [ValidateSet('16', '32', '64')]
    [string]$Stage = '64',
    [switch]$Stress,
    [switch]$InjectFault,
    [switch]$Monitor,
    [ValidateSet('None','divide','invalid','page','general','double','write','execute','guard','stack')]
    [string]$Exception = 'None'
)

$ErrorActionPreference = 'Stop'
if ($Stress -and $Stage -ne '64') { throw '-Stress requiere -Stage 64.' }
if ($InjectFault -and -not $Stress) { throw '-InjectFault requiere -Stress.' }
if ($Exception -ne 'None' -and ($Stage -ne '64' -or $Stress)) {
    throw '-Exception requiere -Stage 64 y no se combina con -Stress.'
}
if ($Monitor -and ($Stage -ne '64' -or $Stress -or $Exception -ne 'None')) { throw '-Monitor requiere 64 bits sin Stress ni Exception.' }
$buildName = "faggin-$Stage"
if ($Monitor) { $buildName += '-monitor' }
if ($Stress) { $buildName += '-stress' }
if ($InjectFault) { $buildName += '-fault' }
if ($Exception -ne 'None') { $buildName += "-exception-$Exception" }
$projectRoot = Split-Path $PSScriptRoot -Parent
$parts = @('16-bit\entry.hex')
if ($Stage -eq '16') { $parts += '16-bit\halt.hex' }
else { $parts += '16-bit\to-32.hex' }
$parts += '16-bit\message.hex'
if ($Stage -ne '16') {
    $parts += @('16-bit\gdt.hex', '32-bit\entry.hex')
    if ($Stage -eq '32') { $parts += '32-bit\halt.hex' }
    else { $parts += '32-bit\to-64.hex' }
    $parts += '32-bit\message.hex'
}
if ($Stage -eq '64') {
    $parts += '64-bit\entry.hex'
    $parts += '64-bit\services\transition.hex'
    $parts += @('64-bit\failure.hex', '64-bit\message.hex')
    if ($Stress) {
        $parts += '64-bit\stress\fill.hex'
        if ($InjectFault) { $parts += '64-bit\stress\corrupt.hex' }
        else { $parts += '64-bit\stress\clean.hex' }
        $parts += @('64-bit\stress\verify.hex', '64-bit\stress\messages.hex')
    }
    $parts += @('64-bit\diagnostics\init.hex', '64-bit\diagnostics\stubs.hex',
        '64-bit\diagnostics\handler.hex', '64-bit\diagnostics\output.hex')
    if ($Exception -ne 'None') { $parts += "64-bit\diagnostics\tests\$Exception.hex" }
    $parts += @('64-bit\diagnostics\messages.hex', '64-bit\diagnostics\pointers.hex')
    $parts += '64-bit\services\self-test.hex'
    if ($Exception -ne 'None') { $parts += '64-bit\services\target-exception.hex' }
    elseif ($Monitor) { $parts += '64-bit\services\target-monitor.hex' }
    elseif ($Stress) { $parts += '64-bit\services\target-stress.hex' }
    else { $parts += '64-bit\services\target-normal.hex' }
    $parts += @('64-bit\services\allocate.hex','64-bit\services\table.hex',
        '64-bit\services\messages.hex','64-bit\services\cases.hex',
        '64-bit\services\state-init.hex','64-bit\services\latch-test.hex',
        '64-bit\services\latch-message.hex')
    if ($Monitor) { $parts += '64-bit\monitor\console.hex' }
}
$parts += '16-bit\reset.hex'

Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force 'build' | Out-Null
    . "$PSScriptRoot\guardians\check-layout.ps1"
    $layout = Import-PowerShellDataFile "$PSScriptRoot\guardians\layout.psd1"
    $guardianReport = Test-FirmwareLayout -Layout $layout -Sources $parts -SourceRoot $PSScriptRoot
    $guardianReport | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "build\$buildName-guardians.json" -Encoding utf8
    foreach ($finding in $guardianReport.Findings) {
        $color = @{GREEN='Green';YELLOW='Yellow';RED='Red'}[$finding.Level]
        $location = $(if ($finding.Line -gt 0) {':'+$finding.Line} else {''})
        Write-Host ('{0} [{1}] {2}{3}: {4}' -f $finding.Level,$finding.Code,$finding.Owner,$location,$finding.Detail) -ForegroundColor $color
        if ($finding.Level -eq 'RED') {
            Write-Host "  Motivo: $($finding.Why)" -ForegroundColor Red
            if ($null -ne $finding.Expected) { Write-Host "  Esperado: $($finding.Expected); encontrado: $($finding.Actual)" -ForegroundColor Red }
            Write-Host "  Correccion: $($finding.Fix)" -ForegroundColor Red
        }
    }
    if (-not $guardianReport.Allowed) { throw "RED: construccion bloqueada por guardianes. Revisa build\$buildName-guardians.json." }
    $combinedHex = [Collections.Generic.List[string]]::new()
    $sourceSizes = @()
    foreach ($part in $parts) {
        $partLines = [string[]](Get-Content -LiteralPath (Join-Path $PSScriptRoot $part))
        $combinedHex.Add("; SOURCE: $part")
        $combinedHex.AddRange($partLines)
        $authoredBytes = 0
        foreach ($partLine in $partLines) {
            $partCode = ($partLine -split ';', 2)[0]
            $authoredBytes += @($partCode -split '\s+' | Where-Object { $_ -match '^[0-9a-fA-F]{2}$' }).Count
        }
        $sourceSizes += [pscustomobject]@{ Source=$part; AuthoredBytes=$authoredBytes }
    }
    $hexPath = "build\$buildName.hex"
    [IO.File]::WriteAllLines((Join-Path $projectRoot $hexPath), $combinedHex)
    & (Join-Path $projectRoot 'build.ps1') -In $hexPath -Out "build\$buildName.rom"
    $romBytes = (Get-Item "build\$buildName.rom").Length
    $totalAuthored = [int]($sourceSizes | Measure-Object AuthoredBytes -Sum).Sum
    [ordered]@{
        Name=$buildName; Stage=$Stage; Stress=[bool]$Stress; InjectFault=[bool]$InjectFault
        Monitor=[bool]$Monitor; Exception=$Exception; RomBytes=$romBytes; AuthoredBytes=$totalAuthored
        GuardianStatus=$guardianReport.Status
        PaddingBytes=($romBytes - $totalAuthored)
        SHA256=(Get-FileHash "build\$buildName.rom" -Algorithm SHA256).Hash
        Sources=$sourceSizes
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "build\$buildName-map.json" -Encoding utf8
}
finally { Pop-Location }
