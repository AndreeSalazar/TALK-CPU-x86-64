# Prototipo de entrada UEFI -> codigo propio, sin modificar firmware de la placa.
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor -AutoBoot
    New-Item -ItemType Directory -Force build/Puente_Metal/EFI/BOOT,build/Puente_Metal/METAL | Out-Null
    $lines=[Collections.Generic.List[string]]::new()
    foreach($name in @('cabecera.hex','entrada.hex','datos.hex','fuente.hex')){
        $lines.Add("; SOURCE: Puente_Metal/$name")
        $lines.AddRange([string[]](Get-Content "Puente_Metal/$name"))
    }
    [IO.File]::WriteAllLines("$PSScriptRoot/build/puente-metal.hex",$lines)
    & "$PSScriptRoot/build.ps1" -In build/puente-metal.hex -Out build/Puente_Metal/EFI/BOOT/BOOTX64.EFI
    Copy-Item build/hola.x86 build/Puente_Metal/METAL/INICIO.X86 -Force
    $entries=@()
    foreach($name in @('EFI/BOOT/BOOTX64.EFI','METAL/INICIO.X86')){
        $file="build/Puente_Metal/$name"
        $entries+=[ordered]@{Ruta=$name;Bytes=(Get-Item $file).Length;SHA256=(Get-FileHash $file -Algorithm SHA256).Hash}
    }
    [ordered]@{Nombre='Puente al Metal';Version='0.1';Entrada='UEFI x64';Salida='ExitBootServices + FAGRAW64 + framebuffer directo';PruebaFisica=$false;Archivos=$entries} |
        ConvertTo-Json -Depth 4 | Set-Content build/Puente_Metal/manifiesto.json -Encoding utf8
    Copy-Item -LiteralPath "$PSScriptRoot/Puente_Metal/PAQUETE.txt" -Destination build/Puente_Metal/LEEME.txt -Force
    Write-Host 'Preparado: build/Puente_Metal. No se ha escrito en SSD/USB fisico.'
}finally{Pop-Location}
