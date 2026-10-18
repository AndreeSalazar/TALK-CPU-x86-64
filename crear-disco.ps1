# Crea un volumen FAT32 de 64 MiB dentro de build/, sin acceder a discos fisicos.
param([string]$Programa,[switch]$Fragmentado,[switch]$MBR,[switch]$GPT,
    [ValidateSet(1,2,4,8,16,32,64)][int]$SectoresPorCluster=1)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/herramientas-imagen.ps1"
if($GPT -and $MBR){throw 'Selecciona GPT o MBR.'}
Push-Location $PSScriptRoot
try {
    if(-not $Programa){
        & "$PSScriptRoot/build.ps1" -In 'Orquestador_Metal/64-bit/storage/inicio.hex' -Out 'build/disco-inicio.x86'
        $Programa='build/disco-inicio.x86'
    }
    $packet=[IO.File]::ReadAllBytes((Join-Path $PWD $Programa))
    if($packet.Length -lt 25 -or $packet.Length -gt 4096 -or [Text.Encoding]::ASCII.GetString($packet,0,8) -cne 'FAGRAW64' -or
       [BitConverter]::ToUInt32($packet,8)+24 -ne $packet.Length){throw 'Se requiere un paquete FAGRAW64 de 25..4096 bytes.'}
    $name=if($Fragmentado){'disco-fat32-fragmentado.img'}else{'disco-fat32.img'}
    if($MBR){$name=if($Fragmentado){'disco-fat32-mbr-fragmentado.img'}else{'disco-fat32-mbr.img'}}
    if($GPT){$name=if($Fragmentado){'disco-fat32-gpt-fragmentado.img'}else{'disco-fat32-gpt.img'}}
    if($SectoresPorCluster -ne 1){$name=$name.Replace('.img',"-c$SectoresPorCluster.img")}
    $volumeStart=if($MBR -or $GPT){2048}else{0}
    $volumeSectors=if($SectoresPorCluster -eq 1){131072}else{2080+65536*$SectoresPorCluster}
    $diskSectors=$volumeStart+$volumeSectors+$(if($GPT){33}else{0})
    $path=Join-Path $PSScriptRoot "build/$name"
    $boot=New-Object byte[] 512
    function Put16($buffer,$offset,[uint16]$value){[Array]::Copy([BitConverter]::GetBytes($value),0,$buffer,$offset,2)}
    function Put32($buffer,$offset,[uint32]$value){[Array]::Copy([BitConverter]::GetBytes($value),0,$buffer,$offset,4)}
    $boot[0]=0xEB;$boot[1]=0x58;$boot[2]=0x90
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('METAL   '),0,$boot,3,8)
    Put16 $boot 11 512;$boot[13]=$SectoresPorCluster;Put16 $boot 14 32;$boot[16]=2;$boot[21]=0xF8
    Put16 $boot 24 63;Put16 $boot 26 255;Put32 $boot 32 $volumeSectors;Put32 $boot 36 1024
    Put32 $boot 28 $volumeStart
    Put32 $boot 44 2;Put16 $boot 48 1;Put16 $boot 50 6
    $boot[64]=0x80;$boot[66]=0x29;Put32 $boot 67 0x4D455441
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('METAL      FAT32   '),0,$boot,71,19)
    $boot[510]=0x55;$boot[511]=0xAA
    $info=New-Object byte[] 512
    Put32 $info 0 0x41615252;Put32 $info 484 0x61417272
    Put32 $info 488 ([uint32]::MaxValue);Put32 $info 492 ([uint32]::MaxValue);Put32 $info 508 ([uint32]2857697280)
    $fat=New-Object byte[] (1024*512)
    Put32 $fat 0 0x0FFFFFF8;Put32 $fat 4 0x0FFFFFFF
    $count=[int][Math]::Ceiling($packet.Length/(512.0*$SectoresPorCluster))
    $clusters=if($Fragmentado){@(4,7,9,11,13,15,17,19)[0..($count-1)]}else{@(4..(3+$count))}
    Put32 $fat 8 $(if($Fragmentado){5}else{0x0FFFFFFF})
    Put32 $fat 12 $(if($Fragmentado){6}else{0x0FFFFFFF})
    if($Fragmentado){Put32 $fat 20 0x0FFFFFFF;Put32 $fat 24 0x0FFFFFFF}
    for($i=0;$i -lt $count;$i++){Put32 $fat ($clusters[$i]*4) $(if($i+1 -lt $count){$clusters[$i+1]}else{0x0FFFFFFF})}
    $root=New-Object byte[] 512
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('METAL      '),0,$root,0,11)
    $root[11]=0x10;Put16 $root 26 3
    $dir=New-Object byte[] 512
    foreach($entry in @(@{Index=0;Name='.          ';Cluster=3},@{Index=32;Name='..         ';Cluster=0})){
        [Array]::Copy([Text.Encoding]::ASCII.GetBytes($entry.Name),0,$dir,$entry.Index,11)
        $dir[$entry.Index+11]=0x10;Put16 $dir ($entry.Index+26) $entry.Cluster
    }
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('INICIO  X86'),0,$dir,64,11)
    $dir[75]=0x20;Put16 $dir 90 $clusters[0];Put32 $dir 92 $packet.Length
    $stream=[IO.File]::Open($path,'Create','Write','None')
    try {
        [MetalImageSupport]::Sparse($stream)
        $stream.SetLength($diskSectors*512L)
        function Write-At([long]$offset,[byte[]]$data){$stream.Position=$offset+$volumeStart*512L;$stream.Write($data,0,$data.Length)}
        Write-At 0 $boot;Write-At 512 $info;Write-At (6*512) $boot;Write-At (7*512) $info
        Write-At (32*512) $fat;Write-At (1056*512) $fat
        if($Fragmentado){
            $deleted=New-Object byte[] (512*$SectoresPorCluster)
            for($i=0;$i -lt $deleted.Length;$i+=32){$deleted[$i]=0xE5}
            Write-At (2080*512) $deleted;Write-At ((2080+$SectoresPorCluster)*512) $deleted
            Write-At ((2080+(5-2)*$SectoresPorCluster)*512) $root;Write-At ((2080+(6-2)*$SectoresPorCluster)*512) $dir
        }else{Write-At (2080*512) $root;Write-At ((2080+$SectoresPorCluster)*512) $dir}
        for($i=0;$i -lt $count;$i++){
            $sector=New-Object byte[] (512*$SectoresPorCluster)
            [Array]::Copy($packet,$i*$sector.Length,$sector,0,[Math]::Min($sector.Length,$packet.Length-$i*$sector.Length))
            Write-At ((2080+($clusters[$i]-2)*$SectoresPorCluster)*512) $sector
        }
        if($MBR -or $GPT){
            $mbrSector=New-Object byte[] 512
            $mbrSector[446]=0x80;$mbrSector[450]=0x0C
            foreach($offset in @(447,451)){$mbrSector[$offset]=0xFE;$mbrSector[$offset+1]=0xFF;$mbrSector[$offset+2]=0xFF}
            Put32 $mbrSector 454 $volumeStart;Put32 $mbrSector 458 $volumeSectors
            if($GPT){$mbrSector[446]=0;$mbrSector[450]=0xEE;Put32 $mbrSector 454 1;Put32 $mbrSector 458 ($diskSectors-1)}
            $mbrSector[510]=0x55;$mbrSector[511]=0xAA
            $stream.Position=0;$stream.Write($mbrSector,0,$mbrSector.Length)
        }
        if($GPT){
            $table=New-Object byte[] 16384
            [Array]::Copy(([guid]'EBD0A0A2-B9E5-4433-87C0-68B6B72699C7').ToByteArray(),0,$table,0,16)
            [Array]::Copy(([guid]'B5505957-0A52-4912-95D2-2710D6750011').ToByteArray(),0,$table,16,16)
            [Array]::Copy([BitConverter]::GetBytes([uint64]$volumeStart),0,$table,32,8)
            [Array]::Copy([BitConverter]::GetBytes([uint64]($volumeStart+$volumeSectors-1)),0,$table,40,8)
            [Array]::Copy([Text.Encoding]::Unicode.GetBytes('Orquestador del Metal'),0,$table,56,40)
            $tableCrc=[MetalImageSupport]::Crc($table,$table.Length)
            foreach($backup in @($false,$true)){
                $header=New-Object byte[] 512
                [Array]::Copy([Text.Encoding]::ASCII.GetBytes('EFI PART'),0,$header,0,8)
                Put32 $header 8 0x10000;Put32 $header 12 92
                $my=if($backup){$diskSectors-1}else{1};$other=if($backup){1}else{$diskSectors-1}
                $tableLba=if($backup){$diskSectors-33}else{2}
                foreach($field in @(@{At=24;Value=$my},@{At=32;Value=$other},@{At=40;Value=34},@{At=48;Value=$diskSectors-34},@{At=72;Value=$tableLba})){
                    [Array]::Copy([BitConverter]::GetBytes([uint64]$field.Value),0,$header,$field.At,8)
                }
                [Array]::Copy(([guid]'D5C32B11-D2A8-4431-9917-14A32C202600').ToByteArray(),0,$header,56,16)
                Put32 $header 80 128;Put32 $header 84 128;Put32 $header 88 $tableCrc
                Put32 $header 16 ([MetalImageSupport]::Crc($header,92))
                $stream.Position=$my*512L;$stream.Write($header,0,512)
                $stream.Position=$tableLba*512L;$stream.Write($table,0,$table.Length)
            }
        }
    }
    finally{$stream.Dispose()}
    Write-Host "FAT32 preparado: $path; METAL/INICIO.X86 = $($packet.Length) bytes."
}
finally{Pop-Location}
