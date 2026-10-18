# Conserva las capturas y los informes de una bateria completada, sin ejecutar firmware.
$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
Push-Location $ProjectRoot
try {
    $reports=@('test-results.json','guardian-test-results.json','program-test-results.json',
        'screen-test-results.json','screen-cursor-test-results.json','storage-test-results.json',
        'gpt-test-results.json','boot-test-results.json')
    $photos=@('01-arranque-gpt.png','02-guardian-gpt.png','03-eco-propio.png','04-sin-disco.png')
    # Comprobar todo antes de reemplazar la instantanea conservada.
    foreach($name in $reports){
        $report=Get-Content "build/$name" -Raw | ConvertFrom-Json
        if($report.PSObject.Properties.Name -contains 'Total'){
            if($report.Passed -ne $report.Total){throw "Bateria incompleta o fallida: $name"}
        }elseif($report.Passed -ne $true){throw "Informe sin aprobacion: $name"}
    }
    foreach($name in $photos){
        $bytes=[IO.File]::ReadAllBytes("$ProjectRoot/build/capturas/$name")
        if($bytes.Length -lt 8 -or [Convert]::ToHexString($bytes[0..7]) -ne '89504E470D0A1A0A'){
            throw "Captura PNG invalida: $name"
        }
    }
    New-Item -ItemType Directory -Force EVIDENCIAS/QEMU/informes | Out-Null
    $entries=@()
    foreach($name in $reports){Copy-Item "build/$name" "EVIDENCIAS/QEMU/informes/$name" -Force}
    foreach($name in $photos){Copy-Item "build/capturas/$name" "EVIDENCIAS/QEMU/$name" -Force}
    foreach($path in @($photos)+@($reports|ForEach-Object {"informes/$_"})){
        $file="EVIDENCIAS/QEMU/$path"
        $entries+=[ordered]@{Ruta=$path;Bytes=(Get-Item -LiteralPath $file).Length;SHA256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    [ordered]@{Recopilado=(Get-Date -Format o);Origen='QEMU: ultima bateria local completada; no prueba de placa fisica';Archivos=$entries} |
        ConvertTo-Json -Depth 5 | Set-Content EVIDENCIAS/QEMU/manifiesto.json -Encoding utf8
    Write-Host 'Evidencias conservadas en EVIDENCIAS/QEMU; informes aprobados y huellas registradas.'
}finally{Pop-Location}
