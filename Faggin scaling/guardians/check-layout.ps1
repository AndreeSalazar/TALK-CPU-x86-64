function Test-FirmwareLayout {
    param([hashtable]$Layout, [string[]]$Sources, [string]$SourceRoot)
    $findings = [Collections.Generic.List[object]]::new()
    $usage = [Collections.Generic.List[object]]::new()
    $windows = @()
    $add = {
        param($level,$guard,$owner,$detail)
        $findings.Add([pscustomobject]@{Level=$level;Guard=$guard;Owner=$owner;Detail=$detail})
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
        if ($window.Start -lt 0 -or $window.End -le $window.Start -or $window.End -gt $Layout.RomBytes) {
            & $add 'RED' 'Budget' $source 'Ventana ROM invalida.'
            continue
        }
        foreach ($previous in $windows) {
            if ($window.Start -lt $previous.End -and $previous.Start -lt $window.End) {
                & $add 'RED' 'Overlap' $source "Ventana cruza la de $($previous.Source)."
            }
        }
        $windows += [pscustomobject]@{Source=$source;Start=$window.Start;End=$window.End}
    }
    $memory = @()
    foreach ($region in $Layout.Memory) {
        if ($region.Start -lt 0 -or $region.End -le $region.Start -or
            $region.End -gt $Layout.MappedBytes -or $region.Alignment -lt 1 -or
            $region.Start % $region.Alignment -ne 0) {
            & $add 'RED' 'Reservation' $region.Name 'Reserva invalida o desalineada.'
        }
        foreach ($previous in $memory) {
            if ($region.Start -lt $previous.End -and $previous.Start -lt $region.End) {
                & $add 'RED' 'Reservation' $region.Name "Reserva cruza la de $($previous.Name)."
            }
        }
        $memory += $region
    }
    $cursor = 0
    $rootPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    foreach ($source in $Sources) {
        if (-not $Layout.Sources.ContainsKey($source)) { continue }
        $window = $Layout.Sources[$source]
        $count = 0
        $lastByteEnd = $window.Start
        try {
            $sourcePath = [IO.Path]::GetFullPath((Join-Path $SourceRoot $source))
            if (-not $sourcePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'La fuente sale de la carpeta del firmware.'
            }
            foreach ($line in Get-Content -LiteralPath $sourcePath -ErrorAction Stop) {
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
