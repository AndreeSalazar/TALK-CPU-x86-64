function Test-FirmwareLayout {
    param([hashtable]$Layout, [string[]]$Sources, [string]$SourceRoot)
    $findings = [Collections.Generic.List[object]]::new()
    $usage = [Collections.Generic.List[object]]::new()
    $encoded = @{}
    $locations = @{}
    $lineNumber = 0
    $cursor = 0
    $advice = @{
        Profile=@('El perfil fijo necesita metadatos completos y tipos validos.','Restaurar el esquema y el perfil QEMU antes de construir.')
        Ownership=@('Todo archivo necesita un propietario y una ventana.','Registrar la fuente y su carril; no omitir el control.')
        Budget=@('Una ventana invalida no define limites fiables.','Corregir Start/End y explicar la reserva en Why.')
        Overlap=@('Dos propietarios no pueden ocupar el mismo carril a la vez.','Separar ventanas o seleccionar solo una variante alternativa.')
        Reservation=@('Una reserva ausente, duplicada o cruzada puede destruir otro recurso.','Restaurar la reserva, su alineacion y sus limites; revisar referencias raw.')
        Encoding=@('Los bytes deben respetar offsets y limites de su propietario.','Corregir la linea indicada o revisar explicitamente el mapa y todas sus referencias.')
        Contract=@('Un cambio puede desactivar una proteccion o romper el ABI.','Revisar codigo, contrato y pruebas juntos; no actualizar el contrato solo para silenciarlo.')
        ROM=@('La CPU espera una imagen completa con el vector en su extremo.','Restaurar reset.hex y comprobar el orden de las fuentes.')
        Margin=@('El bloque tiene poco margen para crecer.','Revisar su presupuesto antes de agregar bytes.')
        Layout=@('Las reglas estructurales comprobadas se cumplen.','Continuar dentro de la cobertura declarada.')
        Coverage=@('La proteccion temprana y la semantica completa aun no estan cubiertas.','Mantener el aviso hasta implementar y probar esa cobertura.')
    }
    $windows = @()
    $validWindows = @{}
    $add = {
        param($level,$guard,$owner,$detail,$expected=$null,$actual=$null,$reason=$null)
        $policy = $advice[$guard]
        $findings.Add([pscustomobject]@{
            Level=$level;Code=('FG-' + $guard.ToUpperInvariant());Guard=$guard;Owner=$owner
            Detail=$detail;Why=$(if ($reason) {$reason} else {$policy[0]});Fix=$policy[1]
            Line=$lineNumber;Offset=$cursor;Expected=$expected;Actual=$actual
        })
    }
    if (-not $Layout -or $Layout.SchemaVersion -ne 1 -or $Layout.Sources -isnot [hashtable] -or
        $Layout.RomBytes -isnot [int] -or $Layout.MappedBytes -isnot [int] -or $Layout.WarningPercent -isnot [int] -or
        -not $Layout.Memory -or -not $Layout.RequiredMemory -or -not $Layout.Contracts -or
        -not $Layout.MemoryContracts -or -not $Sources) {
        & $add 'RED' 'Profile' 'global' 'Falta un campo obligatorio del esquema de guardianes.'
        return [pscustomobject]@{Status='RED';Allowed=$false;Findings=@($findings.ToArray());Usage=@()}
    }
    foreach ($requiredName in @('PML4','PDPT','PD','PT','GDT','TSS','IDT','AllocatorState','GuardMain','StackMain','ROM','WorkRAM')) {
        if ($Layout.RequiredMemory -notcontains $requiredName) { & $add 'RED' 'Profile' $requiredName 'Se elimino un recurso obligatorio de la politica.' }
    }
    if ($Layout.RomBytes -ne 65536 -or $Layout.MappedBytes -ne 0x200000 -or
        $Layout.WarningPercent -lt 1 -or $Layout.WarningPercent -gt 100) {
        & $add 'RED' 'Profile' 'global' 'Perfil incompatible con esta plataforma fija.'
    }
    foreach ($source in $Sources) {
        if (-not $Layout.Sources.ContainsKey($source)) {
            & $add 'RED' 'Ownership' $source 'Fuente sin ventana asignada: registrar su propietario primero.'
            continue
        }
        $window = $Layout.Sources[$source]
        if ($window -isnot [hashtable] -or -not $window.ContainsKey('Start') -or -not $window.ContainsKey('End') -or
            $window.Start -isnot [int] -or $window.End -isnot [int] -or
            -not $window.Why -or $window.Start -lt 0 -or $window.End -le $window.Start -or $window.End -gt $Layout.RomBytes) {
            & $add 'RED' 'Budget' $source 'Ventana ROM invalida.'
            continue
        }
        foreach ($previous in $windows) {
            if ($window.Start -lt $previous.End -and $previous.Start -lt $window.End) {
                & $add 'RED' 'Overlap' $source ('[{0:X},{1:X}) cruza {2} [{3:X},{4:X}).' -f $window.Start,$window.End,$previous.Source,$previous.Start,$previous.End)
            }
        }
        $windows += [pscustomobject]@{Source=$source;Start=$window.Start;End=$window.End}
        $validWindows[$source] = $window
    }
    $memory = @()
    foreach ($region in $Layout.Memory) {
        if ($region -isnot [hashtable] -or $region.Start -isnot [int] -or
            $region.End -isnot [int] -or $region.Alignment -isnot [int]) {
            & $add 'RED' 'Reservation' 'metadata' 'Reserva incompleta o con tipos incorrectos.'
            continue
        }
        if (-not $region.Name -or -not $region.Why -or $region.Start -lt 0 -or $region.End -le $region.Start -or
            $region.End -gt $Layout.MappedBytes -or $region.Alignment -lt 1 -or
            $region.Start % $region.Alignment -ne 0 -or ($region.Alignment -band ($region.Alignment - 1)) -ne 0) {
            & $add 'RED' 'Reservation' $region.Name 'Reserva invalida o desalineada.'
        }
        foreach ($previous in $memory) {
            if ($region.Name -eq $previous.Name) { & $add 'RED' 'Reservation' $region.Name 'Nombre de reserva duplicado.' }
            if ($region.Start -lt $previous.End -and $previous.Start -lt $region.End) {
                & $add 'RED' 'Reservation' $region.Name "Reserva cruza la de $($previous.Name)."
            }
        }
        $memory += $region
    }
    foreach ($required in $Layout.RequiredMemory) {
        if (@($memory | Where-Object Name -eq $required).Count -ne 1) {
            & $add 'RED' 'Reservation' $required 'Debe existir exactamente una reserva para este recurso obligatorio.' 1 @($memory | Where-Object Name -eq $required).Count
        }
    }
    foreach ($contract in $Layout.MemoryContracts) {
        if ($contract -isnot [hashtable] -or -not $contract.Name -or $contract.Start -isnot [int] -or $contract.End -isnot [int]) {
            & $add 'RED' 'Contract' 'metadata' 'Contrato de reserva incompleto o con tipos incorrectos.'
            continue
        }
        $matching = @($memory | Where-Object Name -eq $contract.Name)
        if ($matching.Count -ne 1 -or $matching[0].Start -ne $contract.Start -or $matching[0].End -ne $contract.End) {
            & $add 'RED' 'Contract' $contract.Name 'La reserva no coincide con las direcciones que usa el firmware raw.' ('[{0:X},{1:X})' -f $contract.Start,$contract.End) 'reserva modificada o ausente'
        }
    }
    foreach ($criticalName in @('PT','TSS','IDT','AllocatorState','GuardMain','StackMain','ROM')) {
        if (@($Layout.MemoryContracts | Where-Object Name -eq $criticalName).Count -ne 1) {
            & $add 'RED' 'Contract' $criticalName 'Debe conservarse exactamente un contrato para esta reserva critica.'
        }
    }
    foreach ($criticalAnchor in @(
        @{Source='16-bit\reset.hex';Offset=0xFFF0},
        @{Source='32-bit\to-64.hex';Offset=0x02DB},
        @{Source='32-bit\to-64.hex';Offset=0x02E5},
        @{Source='64-bit\services\table.hex';Offset=0x2608},
        @{Source='64-bit\services\table.hex';Offset=0x2620},
        @{Source='64-bit\services\allocate.hex';Offset=0x2478}
    )) {
        $anchorMatches = @($Layout.Contracts | Where-Object { $_.Source -eq $criticalAnchor.Source -and $_.Offset -eq $criticalAnchor.Offset })
        if ($anchorMatches.Count -ne 1) {
            & $add 'RED' 'Contract' $criticalAnchor.Source 'Se elimino o duplico un contrato de instruccion critico.'
        }
    }
    $cursor = 0
    $rootPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    foreach ($source in $Sources) {
        if (-not $validWindows.ContainsKey($source)) { continue }
        $window = $Layout.Sources[$source]
        $count = 0
        $lastByteEnd = $window.Start
        $lineNumber = 0
        try {
            $sourcePath = [IO.Path]::GetFullPath((Join-Path $SourceRoot $source))
            if (-not $sourcePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'La fuente sale de la carpeta del firmware.'
            }
            foreach ($line in Get-Content -LiteralPath $sourcePath -ErrorAction Stop) {
                $lineNumber++
                foreach ($token in (($line -split ';',2)[0] -split '\s+' | Where-Object { $_ })) {
                    if ($token -match '^@([0-9a-fA-F]+)$') {
                        $target = [Convert]::ToInt32($Matches[1],16)
                        if ($target -lt $cursor -or $target -gt $Layout.RomBytes) { throw "Relleno invalido en $token." }
                        $cursor = $target
                    }
                    elseif ($token -match '^=([0-9a-fA-F]+)$') {
                        if ($cursor -ne [Convert]::ToInt32($Matches[1],16)) { throw "Offset no coincide en $token." }
                    }
                    elseif ($token -match '^[0-9a-fA-F]{2}$') {
                        if ($cursor -lt $window.Start -or $cursor -ge $window.End) {
                            throw ('Byte en {0:X} fuera de ventana [{1:X},{2:X}). {3}' -f $cursor,$window.Start,$window.End,$window.Why)
                        }
                        $encoded[$cursor] = [Convert]::ToByte($token,16)
                        $locations[$cursor] = @{Source=$source;Line=$lineNumber}
                        $cursor++; $count++; $lastByteEnd = $cursor
                    }
                    else { throw "Token invalido: $token." }
                }
            }
            $percent = [Math]::Round(100 * ($lastByteEnd - $window.Start) / ($window.End - $window.Start),1)
            $usage.Add([pscustomobject]@{Source=$source;AuthoredBytes=$count;Start=$window.Start;End=$window.End;UsedPercent=$percent;Why=$window.Why})
            # Los puntos de empalme exactos tienen longitud fija por contrato.
            if ($percent -ge $Layout.WarningPercent -and -not $window.Fixed) {
                & $add 'YELLOW' 'Margin' $source "$percent % del carril ocupado; revisar antes de ampliar."
            }
        }
        catch { & $add 'RED' 'Encoding' $source $_.Exception.Message; break }
    }
    $lineNumber = 0
    foreach ($contract in $Layout.Contracts) {
        if ($contract -isnot [hashtable] -or -not $contract.Source -or
            -not $Layout.Sources.ContainsKey($contract.Source) -or $contract.Offset -isnot [int] -or
            -not $contract.Why -or [string]$contract.Bytes -notmatch '^[0-9a-fA-F]{2}(\s+[0-9a-fA-F]{2})*$') {
            & $add 'RED' 'Contract' 'metadata' 'Contrato de bytes incompleto o mal formado.'
            continue
        }
        if ($Sources -notcontains $contract.Source) { continue }
        if (-not $validWindows.ContainsKey($contract.Source)) { continue }
        $offset = [int]$contract.Offset
        $expected = @($contract.Bytes -split '\s+' | Where-Object { $_ })
        $ownerWindow = $Layout.Sources[$contract.Source]
        if ($offset -lt $ownerWindow.Start -or $offset + $expected.Count -gt $ownerWindow.End) {
            & $add 'RED' 'Contract' $contract.Source 'El contrato apunta fuera del carril de su propietario.'
            continue
        }
        $actual = @()
        $matchesContract = $true
        for ($i=0; $i -lt $expected.Count; $i++) {
            if (-not $encoded.ContainsKey($offset+$i)) { $actual += '--'; $matchesContract=$false }
            else {
                $actual += ('{0:X2}' -f $encoded[$offset+$i])
                if ($encoded[$offset+$i] -ne [Convert]::ToByte($expected[$i],16)) { $matchesContract=$false }
                if ($locations[$offset+$i].Source -ne $contract.Source) { $matchesContract=$false }
            }
        }
        if (-not $matchesContract) {
            $savedCursor = $cursor; $cursor=$offset
            $lineNumber = $(if ($locations.ContainsKey($offset)) {$locations[$offset].Line} else {0})
            & $add 'RED' 'Contract' $contract.Source ('Contrato de bytes roto en ROM {0:X}.' -f $offset) ($expected -join ' ') ($actual -join ' ') $contract.Why
            $cursor = $savedCursor
        }
    }
    $lineNumber = 0
    if ($cursor -ne $Layout.RomBytes) { & $add 'RED' 'ROM' 'global' 'No se completo la ROM de 64 KiB.' }
    $red = @($findings | Where-Object Level -eq 'RED').Count
    if (-not $red) {
        & $add 'GREEN' 'Layout' 'global' 'Fuentes dentro de sus carriles; reservas sin cruces.'
        & $add 'YELLOW' 'Coverage' 'global' 'La proteccion hardware empieza al activar paginacion de 64 bits; no verifica toda la semantica de los bytes.'
    }
    $status = 'GREEN'
    if (@($findings | Where-Object Level -eq 'YELLOW').Count) { $status = 'YELLOW' }
    if ($red) { $status = 'RED' }
    [pscustomobject]@{Status=$status;Allowed=($red -eq 0);Findings=@($findings.ToArray());Usage=@($usage.ToArray())}
}
