# Evidencia real: entrada PS/2 y capturas VGA de QEMU, sin imagenes simuladas.
param([string]$Qemu)
$ErrorActionPreference='Stop'
if(-not $Qemu){$cmd=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue;$Qemu=if($cmd){$cmd.Source}else{Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}}
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor -AutoBoot
    & "$PSScriptRoot/crear-disco.ps1" -GPT -SectoresPorCluster 8
    New-Item -ItemType Directory -Force 'build/capturas'|Out-Null
    Copy-Item 'build/disco-fat32-gpt-c8.img' 'build/arranque-danado.img' -Force
    $stream=[IO.File]::Open("$PSScriptRoot/build/arranque-danado.img",'Open','ReadWrite','None')
    try{$stream.Position=528;$value=$stream.ReadByte();$stream.Position=528;$stream.WriteByte($value -bxor 1)}finally{$stream.Dispose()}
    Add-Type -AssemblyName System.Drawing
    $results=@()
    foreach($case in @(
        @{Name='correcto';Image='build/disco-fat32-gpt-c8.img';Expected=@('GREEN [FAT32] METAL/INICIO.X86','Hola desde mi disco FAT32!');Execute=$true;Photo='01-arranque-gpt'},
        @{Name='danado';Image='build/arranque-danado.img';Expected=@('RED [GPT] header/CRC invalid');Photo='02-guardian-gpt'},
        @{Name='sin-disco';Expected=@('RED [ATA] disk absent');Photo='04-sin-disco'}
    )){
        $passed=$false;$failure=$null;$process=$null
        $base="build/arranque-$($case.Name)"
        try {
            # Comprobar la secuencia sin enviar orden d: el firmware inicia la carga.
            $options=@{Qemu=$Qemu;Check=$true;AutoStartup=$true;DiskExpected=$case.Expected;LogName="arranque-check-$($case.Name)"}
            if($case.Image){$options.DiskImage=$case.Image}
            & "$PSScriptRoot/monitor-session.ps1" @options
            $trace=Get-Content "build/arranque-check-$($case.Name)-instructions.log" -Raw
            if(($trace -match '0x00080000:') -ne [bool]$case.Execute){throw 'El arranque automatico ejecuto un paquete inesperado.'}
            foreach($file in @("$base-serial.log")){if(Test-Path $file){Remove-Item -LiteralPath $file}}
            $arguments="-machine pc -cpu qemu64 -accel tcg -m 16M -smp 1 -bios build/faggin-64-monitor.rom -nodefaults -device VGA,addr=2 -display none -serial file:$base-serial.log -monitor stdio -chardev file,id=debug,path=$base-debug.log -device isa-debugcon,iobase=0xe9,chardev=debug -no-reboot"
            if($case.Image){$arguments+=" -drive file=$($case.Image),format=raw,if=none,id=metal,snapshot=on -device ide-hd,drive=metal,bus=ide.0,unit=0"}
            $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$Qemu;$start.Arguments=$arguments;$start.WorkingDirectory=$PSScriptRoot
            $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
            $process=[Diagnostics.Process]::new();$process.StartInfo=$start;[void]$process.Start()
            $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$timer=[Diagnostics.Stopwatch]::StartNew()
            function Read-Serial {
                if(-not(Test-Path "$base-serial.log")){return ''}
                $s=[IO.File]::Open("$PSScriptRoot/$base-serial.log",'Open','Read','ReadWrite');$reader=[IO.StreamReader]::new($s)
                try{$reader.ReadToEnd()}finally{$reader.Dispose()}
            }
            function Wait-Text([string]$text){
                do{if($process.HasExited -or $timer.Elapsed.TotalSeconds -gt 30){throw "No llego: $text"};Start-Sleep -Milliseconds 15}until((Read-Serial).Contains($text))
            }
            function Send([string]$command){$process.StandardInput.WriteLine($command);$process.StandardInput.Flush()}
            function Capture([string]$name){
                $relative="build/capturas/$name.ppm";$absolute="$PSScriptRoot/$relative"
                if(Test-Path $absolute){Remove-Item -LiteralPath $absolute}
                Send "screendump $relative"
                do {
                    if($timer.Elapsed.TotalSeconds -gt 30){throw 'No se completo la captura.'}
                    Start-Sleep -Milliseconds 20
                    $ready=$false
                    if(Test-Path $absolute){
                        try{
                            $pixels=[IO.File]::ReadAllBytes($absolute)
                            $header=[Text.Encoding]::ASCII.GetString($pixels,0,[Math]::Min(100,$pixels.Length))
                            if($header -match '^P6\s+(\d+)\s+(\d+)\s+255\s'){
                                $width=[int]$Matches[1];$height=[int]$Matches[2];$offset=$Matches[0].Length
                                $ready=$pixels.Length -eq $offset+3*$width*$height
                            }
                        }catch [IO.IOException]{}
                    }
                }until($ready)
                $bitmap=[Drawing.Bitmap]::new($width,$height)
                try{
                    for($y=0;$y -lt $height;$y++){for($x=0;$x -lt $width;$x++){$i=$offset+3*($y*$width+$x);$bitmap.SetPixel($x,$y,[Drawing.Color]::FromArgb($pixels[$i],$pixels[$i+1],$pixels[$i+2]))}}
                    $bitmap.Save("$PSScriptRoot/build/capturas/$name.png",[Drawing.Imaging.ImageFormat]::Png)
                }finally{$bitmap.Dispose()}
            }
            Wait-Text 'GREEN [BOOT] monitor available'
            foreach($text in $case.Expected){if(-not (Read-Serial).Contains($text)){throw "Falta evidencia de arranque: $text"}}
            Capture $case.Photo
            Send 'sendkey e 10';Wait-Text 'ECO64 READY (ESC vuelve)'
            foreach($key in @('shift-m','e','t','a','l','6','4','ret')){Send "sendkey $key 10";Start-Sleep -Milliseconds 40}
            Wait-Text "Metal64`r`n"
            if($case.Execute){Capture '03-eco-propio'}
            Send 'sendkey esc 10';Wait-Text 'ECO64 END'
            Send 'sendkey q 10';Wait-Text 'GREEN [halt] stopped'
            $passed=$true
        }catch{$failure=$_.Exception.Message;Write-Host "RED [BootTest] $($case.Name): $failure"}
        finally{
            if($process){if(-not $process.HasExited){$process.Kill();$process.WaitForExit()};$process.Dispose()}
        }
        $results+=[pscustomobject]@{Name=$case.Name;Passed=$passed;Error=$failure;Capture=$case.Photo+'.png'}
    }
    $count=@($results|Where-Object Passed).Count
    @{Passed=$count;Total=3;Cases=$results}|ConvertTo-Json -Depth 4|Set-Content 'build/boot-test-results.json'
    if($count -ne 3){throw "Arranque: $count de 3 recorridos aprobados."}
    Remove-Item -LiteralPath "$PSScriptRoot/build/arranque-danado.img"
    Write-Host 'OK: arranque GPT, rechazo recuperable, disco ausente y cuatro capturas reales.'
}finally{Pop-Location}
