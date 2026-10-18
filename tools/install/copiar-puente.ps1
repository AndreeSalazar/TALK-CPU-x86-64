# Copia reversible de archivos al volumen elegido. No formatea, no cambia GPT/BCD.
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\?$')][string]$Destino,[switch]$Extraible,
    [ValidateSet('Hello','FlappyPreview')][string]$Profile='Hello')
$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
Push-Location $ProjectRoot
try {
    $profiles=Import-PowerShellDataFile "$PSScriptRoot/profiles.psd1"
    $selected=$profiles[$Profile]
    if($Extraible -and $Profile -ne 'Hello'){throw 'El perfil visual usa una entrada separada en SSD; no admite -Extraible.'}
    $letter=$Destino.Substring(0,1).ToUpperInvariant()
    $volume=Get-Volume -DriveLetter $letter
    $partition=Get-Partition -DriveLetter $letter
    if($volume.FileSystem -ne 'FAT32'){throw 'El destino debe ser FAT32; este script no formatea.'}
    if($partition.IsBoot -or $partition.IsSystem){throw 'El destino es una particion de Windows/sistema. Elige el volumen de pruebas.'}
    if($Extraible -and $volume.DriveType -ne 'Removable'){throw '-Extraible requiere un medio que Windows identifique como extraible. Para el SSD usa la ruta separada.'}
    $targetRoot=[IO.Path]::GetFullPath($letter+':\')
    $package=Join-Path $ProjectRoot $selected.Package
    $manifest=Get-Content (Join-Path $package 'manifiesto.json') -Raw | ConvertFrom-Json
    if($Profile -eq 'FlappyPreview' -and ($manifest.Perfil -ne $Profile -or $manifest.Interactive -ne $false)){throw 'El perfil visual no acepta el juego interactivo.'}
    $allowed=@($selected.SourceEFI,$selected.Packet)
    if(@($manifest.Archivos).Count -ne 2){throw 'Manifiesto del puente inesperado'}
    foreach($entry in $manifest.Archivos){
        if($entry.Ruta -notin $allowed){throw 'Ruta inesperada en manifiesto'}
        if((Get-FileHash (Join-Path $package $entry.Ruta)).Hash -cne $entry.SHA256){throw "Archivo cambiado: $($entry.Ruta)"}
    }
    $backup=Join-Path $targetRoot ('ORQUESTADOR_METAL/respaldo-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $changes=@()
    foreach($entry in $manifest.Archivos){
        $targetRelative=if($entry.Ruta -eq $selected.SourceEFI -and -not $Extraible){$selected.TargetEFI}else{$entry.Ruta}
        $target=[IO.Path]::GetFullPath((Join-Path $targetRoot $targetRelative))
        if(-not $target.StartsWith($targetRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Destino fuera del volumen elegido'}
        $oldHash=$null;$saved=$null
        if(Test-Path -LiteralPath $target){
            $saved=Join-Path $backup $targetRelative
            New-Item -ItemType Directory -Force (Split-Path $saved) | Out-Null
            $oldHash=(Get-FileHash -LiteralPath $target).Hash
            Copy-Item -LiteralPath $target -Destination $saved
            if((Get-FileHash -LiteralPath $saved).Hash -cne $oldHash){throw 'El respaldo no coincide'}
        }
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath (Join-Path $package $entry.Ruta) -Destination $target -Force
        if((Get-FileHash -LiteralPath $target).Hash -cne $entry.SHA256){throw 'La copia al destino no coincide'}
        $changes+=[ordered]@{Ruta=$targetRelative;SHA256=$entry.SHA256;AnteriorSHA256=$oldHash;Respaldo=$saved}
    }
    $record=[ordered]@{Fecha=(Get-Date -Format o);Perfil=$Profile;Destino=$targetRoot;Etiqueta=$volume.FileSystemLabel;DiskNumber=$partition.DiskNumber;
        PartitionNumber=$partition.PartitionNumber;GptType=$partition.GptType;FormatoModificado=$false;ArranqueWindowsModificado=$false;Archivos=$changes}
    New-Item -ItemType Directory -Force (Join-Path $targetRoot 'ORQUESTADOR_METAL') | Out-Null
    $record | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $targetRoot ('ORQUESTADOR_METAL/'+$selected.Record)) -Encoding utf8
    $record | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $ProjectRoot ('build/'+$selected.Prefix+'-instalacion.json')) -Encoding utf8
    Write-Host "Archivos preparados en $targetRoot; huellas verificadas. No se ha cambiado el orden de arranque."
}finally{Pop-Location}
