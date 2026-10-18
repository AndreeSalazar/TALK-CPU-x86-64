# Agrega una opcion separada al firmware; no selecciona ni reinicia el equipo.
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\?$')][string]$Destino,
    [ValidateSet('Hello','FlappyPreview')][string]$Profile='Hello')
$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
Push-Location $ProjectRoot
try {
    $profiles=Import-PowerShellDataFile "$PSScriptRoot/profiles.psd1"
    $selected=$profiles[$Profile]
    $efiPath='\'+$selected.TargetEFI.Replace('/','\')
    $prefix='build/'+$selected.Prefix
    $letter=$Destino.Substring(0,1).ToUpperInvariant()
    $file=$letter+':'+$efiPath
    if(-not(Test-Path -LiteralPath $file)){throw 'Primero copia el puente con tools/install/copiar-puente.ps1, en su ruta separada.'}
    $manifest=Get-Content (Join-Path $ProjectRoot ($selected.Package+'/manifiesto.json')) -Raw | ConvertFrom-Json
    if($Profile -eq 'FlappyPreview' -and ($manifest.Perfil -ne $Profile -or $manifest.Interactive -ne $false)){throw 'El perfil visual no acepta el juego interactivo.'}
    $expected=($manifest.Archivos | Where-Object Ruta -eq $selected.SourceEFI).SHA256
    if((Get-FileHash -LiteralPath $file).Hash -cne $expected){throw 'El .efi instalado no coincide con el paquete comprobado.'}
    $secure=Get-ItemPropertyValue 'HKLM:/SYSTEM/CurrentControlSet/Control/SecureBoot/State' -Name UEFISecureBootEnabled
    if($secure -ne 0){throw 'Este prototipo no esta firmado y Secure Boot esta activo. No se cambiara esa configuracion automaticamente.'}
    $bcd=Join-Path $env:SystemRoot 'System32/bcdedit.exe'
    function Invoke-Bcd([string[]]$Options){
        $output=@(& $bcd @Options 2>&1)
        if($LASTEXITCODE -ne 0){throw ($output -join "`n")}
        return ($output -join "`n")
    }
    $before=Invoke-Bcd @('/enum','firmware','/v')
    $orderMatch=[regex]::Match($before,'(?im)^displayorder\s+((?:\{[0-9a-f-]{36}\}\s*)+)')
    if(-not $orderMatch.Success){throw 'No se pudo identificar el orden de firmware anterior.'}
    $beforeOrder=@([regex]::Matches($orderMatch.Groups[1].Value,'\{[0-9a-fA-F-]{36}\}') | ForEach-Object Value)
    $oldIds=@([regex]::Matches($before,'\{[0-9a-fA-F-]{36}\}') | ForEach-Object Value)
    $logPath=$prefix+'-entrada.json'
    if(Test-Path $logPath){
        $old=Get-Content $logPath -Raw | ConvertFrom-Json
        if($old.Destino -eq $letter+':\' -and $old.Id -in $oldIds){
            $current=Invoke-Bcd @('/enum',$old.Id,'/v')
            if($current -match [regex]::Escape($efiPath) -and $current -match ('partition='+[regex]::Escape($letter+':'))){
                Write-Host "La entrada separada ya existe: $($old.Id)"
                return
            }
            throw 'Existe un registro previo distinto; revisarlo antes de crear otra entrada.'
        }
    }
    # Do not overwrite the installation snapshot on an idempotent read-only rerun.
    $before | Set-Content ($prefix+'-firmware-before.txt') -Encoding utf8
    $newId=$null
    try {
        $copied=Invoke-Bcd @('/copy','{bootmgr}','/d',$selected.Name)
        $idMatch=[regex]::Match($copied,'\{[0-9a-fA-F-]{36}\}')
        if(-not $idMatch.Success){throw 'La copia no devolvio un identificador verificable.'}
        $candidate=$idMatch.Value
        if($candidate -in $oldIds){throw 'El identificador devuelto ya existia; no se modificara.'}
        $newId=$candidate
        Invoke-Bcd @('/set',$newId,'device',('partition='+$letter+':')) | Out-Null
        Invoke-Bcd @('/set',$newId,'path',$efiPath) | Out-Null
        Invoke-Bcd @('/set','{fwbootmgr}','displayorder',$newId,'/addlast') | Out-Null
        $after=Invoke-Bcd @('/enum','firmware','/v')
        $afterMatch=[regex]::Match($after,'(?im)^displayorder\s+((?:\{[0-9a-f-]{36}\}\s*)+)')
        $afterOrder=@([regex]::Matches($afterMatch.Groups[1].Value,'\{[0-9a-fA-F-]{36}\}') | ForEach-Object Value)
        if($afterOrder.Count -ne $beforeOrder.Count+1){throw 'Cambio inesperado en el numero de entradas de arranque.'}
        for($n=0;$n -lt $beforeOrder.Count;$n++){
            if($afterOrder[$n] -ine $beforeOrder[$n]){throw 'El orden previo no quedo preservado.'}
        }
        if($afterOrder[-1] -ine $newId){throw 'La entrada nueva no quedo al final.'}
        $entry=Invoke-Bcd @('/enum',$newId,'/v')
        if($entry -notmatch [regex]::Escape($efiPath) -or $entry -notmatch ('partition='+[regex]::Escape($letter+':'))){throw 'Ruta o volumen de arranque distintos de los esperados.'}
        $after | Set-Content ($prefix+'-firmware-after.txt') -Encoding utf8
        [ordered]@{Id=$newId;Perfil=$Profile;Destino=$letter+':\';Ruta=$efiPath;Nombre=$selected.Name;
            OrdenAnterior=$beforeOrder;OrdenPosterior=$afterOrder;PredeterminadoPreservado=$true;Reiniciado=$false;
            RetirarEntrada="bcdedit /delete $newId"} | ConvertTo-Json -Depth 4 | Set-Content $logPath -Encoding utf8
        Write-Host "Entrada separada creada al final: $newId. El orden previo se conserva. Reinicia manualmente y elige $($selected.Name) con F11."
    }catch{
        $failure=$_
        if($newId){
            Invoke-Bcd @('/delete',$newId) | Out-Null
            Invoke-Bcd (@('/set','{fwbootmgr}','displayorder')+$beforeOrder) | Out-Null
        }
        throw $failure
    }
}finally{Pop-Location}
