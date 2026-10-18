# Pruebas de paquetes en copias de la ROM; nunca cambia los .hex originales.
param([string]$Qemu)
$ErrorActionPreference='Stop'
if (-not $Qemu) {
    $command=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
    $Qemu=if ($command) { $command.Source } else { Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe' }
}
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor
    $image=[IO.File]::ReadAllBytes("$PSScriptRoot/build/faggin-64-monitor.rom")
    $holaSize=[BitConverter]::ToUInt32($image,0x4008)
    foreach ($program in @(@{Name='hola';Offset=0x4000},@{Name='eco';Offset=0x5000})) {
        $packet=[IO.File]::ReadAllBytes("$PSScriptRoot/build/$($program.Name).x86")
        $size=[BitConverter]::ToUInt32($packet,8)
        if ($packet.Length -ne 24+$size -or [Text.Encoding]::ASCII.GetString($packet,0,8) -cne 'FAGRAW64') {
            throw "Exportacion inconsistente: $($program.Name).x86"
        }
        [uint32]$sum=0
        foreach ($value in $packet[24..($packet.Length-1)]) { $sum+=$value }
        if ($sum -ne [BitConverter]::ToUInt32($packet,16)) { throw 'El checksum exportado no coincide.' }
    }
    $cases=@(
        @{Name='magic';Reason='magic';Offset=0x4000;Value=[byte[]]@(0)},
        @{Name='empty';Reason='size';Offset=0x4008;Value=[BitConverter]::GetBytes([uint32]0)},
        @{Name='oversize';Reason='size';Offset=0x4008;Value=[BitConverter]::GetBytes([uint32]0xFE9)},
        @{Name='overflow';Reason='size';Offset=0x4008;Value=[byte[]]@(255,255,255,255)},
        @{Name='entry';Reason='entry';Offset=0x400C;Value=[BitConverter]::GetBytes($holaSize)},
        @{Name='flags';Reason='flags';Offset=0x4014;Value=[byte[]]@(1)},
        @{Name='checksum';Reason='checksum';Offset=0x4010;Value=[byte[]]@(0)},
        @{Name='body';Reason='checksum';Offset=0x4018;Value=[byte[]]@(0)}
    )
    $results=@()
    foreach ($case in $cases) {
        $passed=$false; $failure=$null
        try {
            $copy=[byte[]]$image.Clone()
            [Array]::Copy($case.Value,0,$copy,$case.Offset,$case.Value.Length)
            $name="program-reject-$($case.Name)"
            $path="build/$name.rom"
            [IO.File]::WriteAllBytes("$PSScriptRoot/$path",$copy)
            & "$PSScriptRoot/monitor-session.ps1" -Qemu $Qemu -Check -RomPath $path -LogName $name -Rejection $case.Reason
            $trace=Get-Content "build/$name-instructions.log" -Raw
            if ($trace -match '0x00080000:') { throw 'Un programa rechazado llego a ejecutarse.' }
            $passed=$true
        }
        catch { $failure=$_.Exception.Message; Write-Host "RED [ProgramTest] $($case.Name): $failure" }
        $results += [pscustomobject]@{Name=$case.Name;Passed=$passed;Error=$failure}
    }
    $count=@($results | Where-Object Passed).Count
    @{Passed=$count;Total=$cases.Count;Cases=$results} | ConvertTo-Json -Depth 4 |
        Set-Content 'build/program-test-results.json'
    if ($count -ne $cases.Count) { throw "Solo $count de $($cases.Count) rechazos comprobados." }
    Write-Host "OK: $count paquetes invalidos rechazados por el firmware; monitor operativo tras cada rechazo."
}
finally { Pop-Location }
