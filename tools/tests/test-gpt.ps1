param([string]$Qemu)
$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
. "$ProjectRoot/tools/build/herramientas-imagen.ps1"
if(-not $Qemu){$cmd=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue;$Qemu=if($cmd){$cmd.Source}else{Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}}
Push-Location $ProjectRoot
try {
    & "$ProjectRoot/Orquestador_Metal/build-firmware.ps1" -Monitor
    & "$ProjectRoot/tools/build/crear-disco.ps1" -GPT
    $packet=[IO.File]::ReadAllBytes("$ProjectRoot/build/disco-inicio.x86")
    $large=New-Object byte[] 4096;[Array]::Copy($packet,0,$large,0,$packet.Length)
    [Array]::Copy([BitConverter]::GetBytes([uint32]4072),0,$large,8,4)
    [IO.File]::WriteAllBytes("$ProjectRoot/build/gpt-large.x86",$large)
    $green='GREEN [FAT32] METAL/INICIO.X86';$hello='Hola desde mi disco FAT32!'
    function Patch($s,[long]$offset,[byte[]]$value){$s.Position=$offset;$s.Write($value,0,$value.Length)}
    function Read-Bytes($s,[long]$offset,[int]$length){$s.Position=$offset;$bytes=New-Object byte[] $length;if($s.Read($bytes,0,$length) -ne $length){throw 'Lectura incompleta de fixture'};return ,$bytes}
    function Fix-Headers($s,[Nullable[uint32]]$ArrayCRC=$null){
        foreach($lba in @(1,($s.Length/512-1))){
            $header=Read-Bytes $s ($lba*512) 512
            if($null -ne $ArrayCRC){[Array]::Copy([BitConverter]::GetBytes([uint32]$ArrayCRC),0,$header,88,4)}
            [Array]::Clear($header,16,4)
            [Array]::Copy([BitConverter]::GetBytes([MetalImageSupport]::Crc($header,92)),0,$header,16,4)
            Patch $s ($lba*512) $header
        }
    }
    function Change-Table($s,[scriptblock]$change){
        $table=Read-Bytes $s 1024 16384
        & $change $table
        Patch $s 1024 $table;Patch $s (($s.Length/512-33)*512) $table
        Fix-Headers $s ([MetalImageSupport]::Crc($table,$table.Length))
    }
    $cases=@(
        @{Name='valid';Execute=$true},
        @{Name='header-crc';Expected='RED [GPT] header/CRC invalid';Mutate={param($s) $b=Read-Bytes $s 528 1;$b[0]=$b[0] -bxor 1;Patch $s 528 $b}},
        @{Name='backup-crc';Expected='RED [GPT] header/CRC invalid';Mutate={param($s) Patch $s ($s.Length-512+16) ([byte[]]@(0,0,0,0))}},
        @{Name='table-crc';Expected='RED [GPT] table CRC invalid';Mutate={param($s) Patch $s 1024 ([byte[]]@(0))}},
        @{Name='backup-table';Expected='RED [GPT] backup mismatch';Mutate={param($s) Patch $s ($s.Length-33*512) ([byte[]]@(0))}},
        @{Name='backup-guid';Expected='RED [GPT] backup mismatch';Mutate={param($s) $b=Read-Bytes $s ($s.Length-512+56) 1;$b[0]=$b[0] -bxor 1;Patch $s ($s.Length-512+56) $b;Fix-Headers $s}},
        @{Name='table-shape';Expected='RED [GPT] unsupported table layout';Mutate={param($s) Patch $s 592 ([BitConverter]::GetBytes([uint32]64));Fix-Headers $s}},
        @{Name='large-lba';Expected='RED [GPT] partitions invalid/ambiguous';Mutate={param($s) Change-Table $s {param($t) $t[36]=1}}},
        @{Name='missing';Expected='RED [GPT] FAT candidate missing';Mutate={param($s) Change-Table $s {param($t) [Array]::Clear($t,0,128)}}},
        @{Name='unused-dirty';Expected='RED [GPT] partitions invalid/ambiguous';Mutate={param($s) Change-Table $s {param($t) $t[128+56]=1}}},
        @{Name='overlap';Expected='RED [GPT] partitions invalid/ambiguous';Mutate={param($s) Change-Table $s {param($t) [Array]::Copy($t,0,$t,128,128);$t[144]=$t[144] -bxor 1}}},
        @{Name='ambiguous';Expected='RED [GPT] partitions invalid/ambiguous';Mutate={param($s) Change-Table $s {param($t)
            [Array]::Copy($t,0,$t,128,128);$t[144]=$t[144] -bxor 1
            [Array]::Copy([BitConverter]::GetBytes([uint64]67583),0,$t,40,8)
            [Array]::Copy([BitConverter]::GetBytes([uint64]67584),0,$t,160,8)
        }}},
        @{Name='duplicate-guid';Expected='RED [GPT] partitions invalid/ambiguous';Mutate={param($s) Change-Table $s {param($t)
            [Array]::Copy($t,0,$t,128,128);$t[128]=0xAA
            [Array]::Copy([BitConverter]::GetBytes([uint64]67583),0,$t,40,8)
            [Array]::Copy([BitConverter]::GetBytes([uint64]67584),0,$t,160,8)
        }}},
        @{Name='esp';Execute=$true;Mutate={param($s) Change-Table $s {param($t) [Array]::Copy(([guid]'C12A7328-F81F-11D2-BA4B-00A0C93EC93B').ToByteArray(),0,$t,0,16)}}},
        @{Name='last-entry';Execute=$true;Mutate={param($s) Change-Table $s {param($t) [Array]::Copy($t,0,$t,127*128,128);[Array]::Clear($t,0,128)}}},
        @{Name='protective';Expected='RED [GPT] header/CRC invalid';Mutate={param($s) Patch $s 454 ([BitConverter]::GetBytes([uint32]2))}}
    )
    foreach($spc in @(2,4,8,16,32,64)){
        & "$ProjectRoot/tools/build/crear-disco.ps1" -GPT -SectoresPorCluster $spc -Programa build/gpt-large.x86
        $cases+=@{Name="cluster-$spc";Execute=$true;Image="build/disco-fat32-gpt-c$spc.img";Clean=($spc -ge 16)}
    }
    & "$ProjectRoot/tools/build/crear-disco.ps1" -GPT -SectoresPorCluster 2 -Fragmentado -Programa build/gpt-large.x86
    $cases+=@{Name='fragmented-c2';Execute=$true;Image='build/disco-fat32-gpt-fragmentado-c2.img'}
    $cases+=@{Name='second-directory-sector';Execute=$true;Image='build/disco-fat32-gpt-c2.img';Mutate={param($s)
        foreach($pair in @(@{At=(2048+2080)*512;Entry=0},@{At=(2048+2080+2)*512;Entry=64})){
            $data=Read-Bytes $s $pair.At 512;$entry=New-Object byte[] 32;[Array]::Copy($data,$pair.Entry,$entry,0,32)
            $deleted=New-Object byte[] 512;for($i=0;$i -lt 512;$i+=32){$deleted[$i]=0xE5}
            Patch $s $pair.At $deleted;Patch $s ($pair.At+512) $entry
        }
    }}
    $results=@()
    foreach($case in $cases){
        $passed=$false;$failure=$null;$path=$null;$name="gpt-$($case.Name)"
        try {
            $image=if($case.Image){$case.Image}else{'build/disco-fat32-gpt.img'}
            if($case.Mutate){$path="build/$name.img";Copy-Item $image $path -Force;$stream=[IO.File]::Open("$ProjectRoot/$path",'Open','ReadWrite','None');try{& $case.Mutate $stream}finally{$stream.Dispose()};$image=$path}
            $expected=if($case.Execute){@($green,$hello)}else{@($case.Expected)}
            $before=(Get-FileHash $image).Hash
            & "$ProjectRoot/tools/qemu/monitor-session.ps1" -Qemu $Qemu -Check -DiskImage $image -LogName $name -DiskExpected $expected
            $trace=Get-Content "build/$name-instructions.log" -Raw
            if(($trace -match '0x00080000:') -ne [bool]$case.Execute){throw 'Ejecucion inesperada tras validacion GPT.'}
            if((Get-FileHash $image).Hash -cne $before){throw 'La imagen base cambio.'}
            $passed=$true
        }catch{$failure=$_.Exception.Message;Write-Host "RED [GPTTest] $name : $failure"}
        if($passed -and $path){Remove-Item -LiteralPath "$ProjectRoot/$path"}
        if($passed -and $case.Clean){Remove-Item -LiteralPath "$ProjectRoot/$($case.Image)"}
        $results+=[pscustomobject]@{Name=$case.Name;Passed=$passed;Error=$failure}
    }
    $count=@($results|Where-Object Passed).Count
    @{Passed=$count;Total=$cases.Count;Cases=$results}|ConvertTo-Json -Depth 4|Set-Content 'build/gpt-test-results.json'
    if($count -ne $cases.Count){throw "GPT: $count de $($cases.Count) pruebas aprobadas."}
    Write-Host "OK: $count casos GPT/CRC y clusters; monitor recuperable y base sin cambios."
}finally{Pop-Location}
