# Cada imagen es un archivo de build/. Se altera una copia para cada rechazo.
param([string]$Qemu)
$ErrorActionPreference='Stop'
if(-not $Qemu){
    $command=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
    $Qemu=if($command){$command.Source}else{Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
}
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor
    & "$PSScriptRoot/crear-disco.ps1"
    $original='build/disco-fat32.img'
    $packet=[IO.File]::ReadAllBytes("$PSScriptRoot/build/disco-inicio.x86")
    $large=New-Object byte[] 1124
    [Array]::Copy($packet,0,$large,0,$packet.Length)
    [Array]::Copy([BitConverter]::GetBytes([uint32]1100),0,$large,8,4)
    # El relleno es cero: la suma del cuerpo no cambia y las instrucciones son identicas.
    [IO.File]::WriteAllBytes("$PSScriptRoot/build/disco-fragmentado.x86",$large)
    & "$PSScriptRoot/crear-disco.ps1" -Programa build/disco-fragmentado.x86 -Fragmentado
    & "$PSScriptRoot/crear-disco.ps1" -MBR
    & "$PSScriptRoot/crear-disco.ps1" -Programa build/disco-fragmentado.x86 -Fragmentado -MBR
    $green='GREEN [FAT32] METAL/INICIO.X86'
    $hello='Hola desde mi disco FAT32!'
    $data=2080*512
    $file=2082*512
    $cases=@(
        @{Name='valid';Expected=@($green,$hello);Execute=$true;Mutate=$null},
        @{Name='fragmented';Image='build/disco-fat32-fragmentado.img';Expected=@($green,$hello);Execute=$true;Mutate=$null},
        @{Name='absent';NoDisk=$true;Expected=@('RED [ATA] disk absent');Mutate=$null},
        @{Name='bpb';Expected=@('RED [FAT32] unsupported/invalid BPB');Mutate={param($s) Write-Patch $s 11 ([byte[]]@(0,0))}},
        @{Name='spc';Expected=@('RED [FAT32] unsupported/invalid BPB');Mutate={param($s) Write-Patch $s 13 ([byte[]]@(2))}},
        @{Name='missing';Expected=@('RED [FAT32] METAL/INICIO.X86 missing');Mutate={param($s) Write-Patch $s $data ([byte[]]@(0))}},
        @{Name='cluster';Expected=@('RED [FAT32] cluster out of range');Mutate={param($s) Write-Patch $s 44 ([BitConverter]::GetBytes([uint32]1))}},
        @{Name='cycle';Expected=@('RED [FAT32] chain loop/length limit');Mutate={param($s)
            $deleted=New-Object byte[] 512
            for($i=0;$i -lt 512;$i+=32){$deleted[$i]=0xE5}
            Write-Patch $s $data $deleted
            Write-Patch $s (32*512+8) ([BitConverter]::GetBytes([uint32]2))
            Write-Patch $s (1056*512+8) ([BitConverter]::GetBytes([uint32]2))
        }},
        @{Name='mirrors';Expected=@('RED [FAT32] FAT copies differ');Mutate={param($s) Write-Patch $s (1056*512+16) ([BitConverter]::GetBytes([uint32]7))}},
        @{Name='truncated';Expected=@('RED [FAT32] truncated chain');Mutate={param($s) Write-Patch $s ($data+512+92) ([BitConverter]::GetBytes([uint32]600))}},
        @{Name='longchain';Expected=@('RED [FAT32] chain loop/length limit');Mutate={param($s)
            Write-Patch $s (32*512+16) ([BitConverter]::GetBytes([uint32]7))
            Write-Patch $s (1056*512+16) ([BitConverter]::GetBytes([uint32]7))
        }},
        @{Name='size';Expected=@('RED [FAT32] file size out of range');Mutate={param($s) Write-Patch $s ($data+512+92) ([BitConverter]::GetBytes([uint32]4097))}},
        @{Name='length';Expected=@('RED [FAT32] packet length mismatch');Mutate={param($s) Write-Patch $s ($data+512+92) ([BitConverter]::GetBytes([uint32]66))}},
        @{Name='checksum';Expected=@($green,'RED [load] checksum');Mutate={param($s) Write-Patch $s ($file+24) ([byte[]]@(0))}}
    )
    $mbrImage='build/disco-fat32-mbr.img'
    $mbrCases=@(
        @{Name='mbr-valid';Expected=@($green,$hello);Execute=$true;Mutate=$null},
        @{Name='mbr-slot4';Expected=@($green,$hello);Execute=$true;Mutate={param($s)
            Write-Patch $s 446 (New-Object byte[] 16)
            Write-Patch $s 494 ([byte[]]@(0x80,0xFE,0xFF,0xFF,0x0C,0xFE,0xFF,0xFF,0,8,0,0,0,0,2,0))
        }},
        @{Name='mbr-fragmented';Image='build/disco-fat32-mbr-fragmentado.img';Expected=@($green,$hello);Execute=$true;Mutate=$null},
        @{Name='mbr-missing';Expected=@('RED [MBR] FAT32 partition missing');Mutate={param($s) Write-Patch $s 446 (New-Object byte[] 64)}},
        @{Name='mbr-zero-start';Expected=@('RED [MBR] invalid table/signature');Mutate={param($s) Write-Patch $s 454 ([BitConverter]::GetBytes([uint32]0))}},
        @{Name='mbr-flag';Expected=@('RED [MBR] invalid table/signature');Mutate={param($s) Write-Patch $s 446 ([byte[]]@(1))}},
        @{Name='mbr-overflow';Expected=@('RED [MBR] partition outside disk');Mutate={param($s) Write-Patch $s 454 ([BitConverter]::GetBytes([uint32]::MaxValue))}},
        @{Name='mbr-overlap';Expected=@('RED [MBR] overlapping/ambiguous partitions');Mutate={param($s)
            $entry=New-Object byte[] 16;$entry[4]=0x83
            [Array]::Copy([BitConverter]::GetBytes([uint32]2049),0,$entry,8,4)
            [Array]::Copy([BitConverter]::GetBytes([uint32]1),0,$entry,12,4)
            Write-Patch $s 462 $entry
        }},
        @{Name='mbr-ambiguous';Expected=@('RED [MBR] overlapping/ambiguous partitions');Mutate={param($s)
            Write-Patch $s 458 ([BitConverter]::GetBytes([uint32]65536))
            $entry=New-Object byte[] 16;$entry[4]=0x0C
            [Array]::Copy([BitConverter]::GetBytes([uint32]67584),0,$entry,8,4)
            [Array]::Copy([BitConverter]::GetBytes([uint32]65536),0,$entry,12,4)
            Write-Patch $s 462 $entry
        }},
        @{Name='mbr-gpt';Expected=@('RED [MBR] GPT not supported yet');Mutate={param($s) Write-Patch $s 450 ([byte[]]@(0xEE))}},
        @{Name='mbr-short-volume';Expected=@('RED [FAT32] unsupported/invalid BPB');Mutate={param($s) Write-Patch $s 458 ([BitConverter]::GetBytes([uint32]131071))}},
        @{Name='mbr-signature';Expected=@('RED [MBR] invalid table/signature');Mutate={param($s) Write-Patch $s 510 ([byte[]]@(0,0))}}
    )
    foreach($case in $mbrCases){if(-not $case.Image){$case.Image=$mbrImage};$cases+=$case}
    function Write-Patch($stream,[long]$offset,[byte[]]$value){$stream.Position=$offset;$stream.Write($value,0,$value.Length)}
    $results=@()
    foreach($case in $cases){
        $passed=$false;$failure=$null
        $name="fat32-$($case.Name)"
        try {
            $options=@{Qemu=$Qemu;Check=$true;LogName=$name;DiskExpected=$case.Expected}
            if(-not $case.NoDisk){
                $source=if($case.Image){$case.Image}else{$original}
                if($case.Mutate){
                    $path="build/$name.img"
                    Copy-Item -LiteralPath $source -Destination $path -Force
                    $stream=[IO.File]::Open("$PSScriptRoot/$path",'Open','Write','None')
                    try{& $case.Mutate $stream}finally{$stream.Dispose()}
                    $source=$path
                }
                $options.DiskImage=$source
                $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
            }
            & "$PSScriptRoot/monitor-session.ps1" @options
            $trace=Get-Content "build/$name-instructions.log" -Raw
            $executed=$trace -match '0x00080000:'
            if($executed -ne [bool]$case.Execute){throw 'La ejecucion del paquete no coincide con el rechazo esperado.'}
            if(-not $case.NoDisk -and (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $before){throw 'La imagen fue modificada durante la lectura.'}
            $passed=$true
        }
        catch{$failure=$_.Exception.Message;Write-Host "RED [StorageTest] $name : $failure"}
        # No acumular imagenes de 64 MiB por cada caso aprobado. Guardar los fallos para inspeccion.
        if($passed -and $case.Mutate){Remove-Item -LiteralPath (Join-Path $PSScriptRoot $path)}
        $results += [pscustomobject]@{Name=$case.Name;Passed=$passed;Error=$failure}
    }
    $count=@($results | Where-Object Passed).Count
    @{Passed=$count;Total=$cases.Count;Cases=$results}|ConvertTo-Json -Depth 4|Set-Content 'build/storage-test-results.json'
    if($count -ne $cases.Count){throw "Solo $count de $($cases.Count) pruebas FAT32 aprobadas."}
    Write-Host "OK: $count recorridos FAT32; ejecucion externa, fragmentacion, rechazos y monitor recuperable."
}
finally{Pop-Location}
