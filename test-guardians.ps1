# Pruebas de reglas con copias de metadatos. No modifica fuentes ni ROM.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Orquestador_Metal\guardians\check-layout.ps1"
$layoutPath = "$PSScriptRoot\Orquestador_Metal\guardians\layout.psd1"
$sourceRoot = "$PSScriptRoot\Orquestador_Metal"
$baselineSources = @('16-bit\entry.hex','16-bit\halt.hex','16-bit\message.hex','16-bit\reset.hex')
$tests = @(
    @{Name='Distribucion valida';Allowed=$true;Guard='Layout';Level='GREEN';Mutate=$null},
    @{Name='Cruce de carriles ROM';Allowed=$false;Guard='Overlap';Level='RED';Mutate={param($layout) $layout.Sources['16-bit\halt.hex'].Start=0x10}},
    @{Name='Cruce de reservas RAM';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'IDT').Start=0x7000}},
    @{Name='Bytes exceden su presupuesto';Allowed=$false;Guard='Encoding';Level='RED';Mutate={param($layout) $layout.Sources['16-bit\message.hex'].End=0x90}},
    @{Name='Fuente sin propietario';Allowed=$false;Guard='Ownership';Level='RED';Extra='README.md';Mutate=$null},
    @{Name='Reserva desalineada';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'TSS').Start=0x7001}},
    @{Name='Imagen incompatible';Allowed=$false;Guard='Profile';Level='RED';Mutate={param($layout) $layout.RomBytes=0x8000}},
    @{Name='Margen reducido avisa sin bloquear';Allowed=$true;Guard='Margin';Level='YELLOW';Mutate={param($layout) $layout.Sources['16-bit\message.hex'].End=0xA0}},
    @{Name='Esquema incompleto bloquea';Allowed=$false;Guard='Profile';Level='RED';Mutate={param($layout) $layout.Sources=$null}},
    @{Name='Reserva critica ausente';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) $layout.Memory=@($layout.Memory | Where-Object Name -ne 'TSS')}},
    @{Name='Reserva duplicada';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) $layout.Memory+= $layout.Memory[0].Clone()}},
    @{Name='Alineacion no potencia de dos';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'GDT').Alignment=3}},
    @{Name='Reserva movida rompe contrato';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'AllocatorState').End=0x9010}},
    @{Name='Contrato de reset roto';Allowed=$false;Guard='Contract';Level='RED';CorruptReset=$true;Mutate=$null},
    @{Name='Contrato mal formado bloquea';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) ($layout.Contracts | Where-Object Source -eq '16-bit\reset.hex').Bytes='XX'}},
    @{Name='Politica de recursos recortada';Allowed=$false;Guard='Profile';Level='RED';Mutate={param($layout) $layout.RequiredMemory=@('ROM')}},
    @{Name='Limite no numerico';Allowed=$false;Guard='Budget';Level='RED';Mutate={param($layout) $layout.Sources['16-bit\message.hex'].End='grande'}},
    @{Name='Contrato obligatorio eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '16-bit\reset.hex')}},
    @{Name='Contrato de reserva eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.MemoryContracts=@($layout.MemoryContracts | Where-Object Name -ne 'AllocatorState')}},
    @{Name='Pagina de programas movida';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'ProgramPage').Start=0x7F000}},
    @{Name='Contrato de permisos eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\programs\loader.hex')}},
    @{Name='Estado de consola cruza asignador';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'ConsoleState').Start=0x9010}},
    @{Name='Limite de cursor eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\screen\video.hex')}},
    @{Name='Paquete de disco cruza sector';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'DiskPacket').Start=0xA000}},
    @{Name='Sector de disco recortado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'SectorBuffer').End=0xA100}},
    @{Name='Limite ATA eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\storage\ata.hex')}},
    @{Name='Contrato de cluster eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\storage\fat32.hex')}},
    @{Name='Volumen cruza estado de disco';Allowed=$false;Guard='Reservation';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'VolumeState').Start=0x9050}},
    @{Name='Limite de particion eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\storage\volumes.hex')}},
    @{Name='Tabla GPT recortada';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) ($layout.Memory | Where-Object Name -eq 'GPTBuffer').End=0x10000}},
    @{Name='Contrato CRC eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\storage\gpt.hex')}},
    @{Name='Limite de sector eliminado';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\storage\fat32-clusters.hex')}},
    @{Name='Politica de arranque eliminada';Allowed=$false;Guard='Contract';Level='RED';Mutate={param($layout) $layout.Contracts=@($layout.Contracts | Where-Object Source -ne '64-bit\monitor\startup.hex')}}
)
$results = @()
foreach ($test in $tests) {
    $layout = Import-PowerShellDataFile $layoutPath
    if ($test.Mutate) { & ($test.Mutate) $layout }
    $sources = $baselineSources
    if ($test.Extra) { $sources += $test.Extra }
    $caseRoot = $sourceRoot
    if ($test.CorruptReset) {
        # Alterar solo una copia de prueba en build; las fuentes reales quedan intactas.
        $caseRoot = Join-Path $PSScriptRoot 'build\guardian-fixture'
        foreach ($sourceName in $baselineSources) {
            $fixturePath = Join-Path $caseRoot $sourceName
            New-Item -ItemType Directory -Force (Split-Path $fixturePath -Parent) | Out-Null
            Copy-Item -LiteralPath (Join-Path $sourceRoot $sourceName) -Destination $fixturePath -Force
        }
        $resetCopy = Join-Path $caseRoot '16-bit\reset.hex'
        [IO.File]::WriteAllText($resetCopy, ([IO.File]::ReadAllText($resetCopy).Replace('EA 00 00 00 F0','EB 00 00 00 F0')))
    }
    $report = Test-FirmwareLayout -Layout $layout -Sources $sources -SourceRoot $caseRoot
    if ($test.Name -eq 'Contrato de reset roto') {
        New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'build') | Out-Null
        $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build\guardian-example.json') -Encoding utf8
    }
    $matching = @($report.Findings | Where-Object { $_.Guard -eq $test.Guard -and $_.Level -eq $test.Level })
    $unexplained = @($report.Findings | Where-Object { $_.Level -eq 'RED' -and (-not $_.Code -or -not $_.Why -or -not $_.Fix) })
    $passed = $report.Allowed -eq $test.Allowed -and $matching.Count -gt 0 -and $unexplained.Count -eq 0
    $results += [pscustomobject]@{Name=$test.Name;Passed=$passed;Expected=$test.Level;Observed=$report.Status}
    if ($passed) { Write-Host "GREEN [GuardianTest] $($test.Name): regla comprobada ($($test.Level))." -ForegroundColor Green }
    else { Write-Host "RED [GuardianTest] $($test.Name): resultado inesperado." -ForegroundColor Red }
}
$passedCount = @($results | Where-Object Passed).Count
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'build') | Out-Null
[ordered]@{Passed=$passedCount;Total=$results.Count;Cases=$results} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build\guardian-test-results.json') -Encoding utf8
if ($passedCount -ne $results.Count) { throw "RED: solo $passedCount de $($results.Count) reglas comprobadas." }
