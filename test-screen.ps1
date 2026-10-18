# Teclas PS/2 reales de la VM y captura de su VGA; no usa funciones de BIOS.
param([string]$Qemu,[switch]$InjectCursorFault)
$ErrorActionPreference='Stop'
if (-not $Qemu) {
    $command=Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
    $Qemu=if ($command) {$command.Source} else {Join-Path $env:ProgramFiles 'qemu/qemu-system-x86_64.exe'}
}
Push-Location $PSScriptRoot
$process=$null
try {
    & "$PSScriptRoot/Orquestador_Metal/build-firmware.ps1" -Monitor
    $base='build/screen-test'
    $rom='build/faggin-64-monitor.rom'
    if($InjectCursorFault){
        $base='build/screen-cursor-test'
        $rom="$base.rom"
        # Solo copia de prueba: desviar una llamada a un inyector en hueco libre.
        $image=[IO.File]::ReadAllBytes("$PSScriptRoot/build/faggin-64-monitor.rom")
        [byte[]]$redirect=0xE8,0x51,0,0,0
        [byte[]]$injector=0xC7,0x04,0x25,0x20,0x90,0,0,0xD0,0x07,0,0,0xE8,0x90,0x07,0,0,0xC3
        [Array]::Copy($redirect,0,$image,0x600A,$redirect.Length)
        [Array]::Copy($injector,0,$image,0x6060,$injector.Length)
        [IO.File]::WriteAllBytes("$PSScriptRoot/$rom",$image)
    }
    $serial="$PSScriptRoot/$base-serial.log"
    $vram="$PSScriptRoot/$base-vram.bin"
    $ppmRelative=if($InjectCursorFault){'build/screen-cursor-test.ppm'}else{'build/orquestador-metal.ppm'}
    $ppm="$PSScriptRoot/$ppmRelative"
    $scrollVram="$PSScriptRoot/$base-scroll.bin"
    $statePath="$PSScriptRoot/$base-state.bin"
    foreach($file in @($serial,$vram,$ppm,$scrollVram,$statePath)){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file}}
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Qemu
    $start.Arguments="-machine pc -cpu qemu64 -accel tcg -m 16M -smp 1 -bios $rom -nodefaults -device VGA,addr=2 -display none -serial file:$base-serial.log -monitor stdio -chardev file,id=debug,path=$base-debug.log -device isa-debugcon,iobase=0xe9,chardev=debug -no-reboot -d in_asm,int -D $base-instructions.log"
    $start.WorkingDirectory=$PSScriptRoot
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    [void]$process.Start()
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $timer=[Diagnostics.Stopwatch]::StartNew()
    function Read-Shared([string]$path) {
        if(-not (Test-Path -LiteralPath $path)){return ''}
        $stream=[IO.File]::Open($path,'Open','Read','ReadWrite')
        $reader=[IO.StreamReader]::new($stream)
        try {$reader.ReadToEnd()} finally {$reader.Dispose()}
    }
    function Wait-Serial([string]$expected) {
        do {
            if($process.HasExited){throw "QEMU termino: $($stderr.GetAwaiter().GetResult())"}
            if($timer.Elapsed.TotalSeconds -gt 30){throw "No llego: $expected"}
            $text=Read-Shared $serial
            Start-Sleep -Milliseconds 10
        } until($text.Contains($expected))
    }
    function Send-Monitor([string]$command) {$process.StandardInput.WriteLine($command);$process.StandardInput.Flush()}
    Wait-Serial 'Orquestador del Metal: listo (64 bits)'
    Send-Monitor 'sendkey o 10'
    Wait-Serial 'Hola mundo desde mi .hex!'
    Send-Monitor 'sendkey e 10'
    Wait-Serial 'ECO64 READY (ESC vuelve)'
    foreach($key in @('shift-h','o','l','a','backspace','a','ret')) {
        Send-Monitor "sendkey $key 10"
        Start-Sleep -Milliseconds 40
    }
    Wait-Serial "Hola`b `ba`r`n"
    Send-Monitor 'sendkey esc 10'
    Wait-Serial 'ECO64 END'
    Send-Monitor "screendump $ppmRelative"
    Send-Monitor "pmemsave 0xb8000 4000 $base-vram.bin"
    do {
        if($timer.Elapsed.TotalSeconds -gt 30){throw 'No se guardo la captura VGA.'}
        Start-Sleep -Milliseconds 20
    } until((Test-Path $ppm) -and (Test-Path $vram) -and (Get-Item $vram).Length -eq 4000)
    $bytes=[IO.File]::ReadAllBytes($vram)
    $characters=New-Object byte[] 2000
    for($i=0;$i -lt 2000;$i++){$characters[$i]=$bytes[$i*2]}
    $screen=[Text.Encoding]::ASCII.GetString($characters)
    foreach($expected in @('Orquestador del Metal','Hola mundo desde mi .hex!','ECO64 READY','Hola','ECO64 END')) {
        if(-not $screen.Contains($expected)){throw "Falta texto en VGA: $expected"}
    }
    if(-not $InjectCursorFault){
        # Exportacion visual de la captura real de QEMU para revisar las letras.
        Add-Type -AssemblyName System.Drawing
        $pixels=[IO.File]::ReadAllBytes($ppm)
        $header=[Text.Encoding]::ASCII.GetString($pixels,0,[Math]::Min(100,$pixels.Length))
        if($header -notmatch '^P6\s+(\d+)\s+(\d+)\s+255\s'){throw 'Cabecera PPM inesperada.'}
        $width=[int]$Matches[1];$height=[int]$Matches[2];$offset=$Matches[0].Length
        $bitmap=[Drawing.Bitmap]::new($width,$height)
        try {
            for($y=0;$y -lt $height;$y++){for($x=0;$x -lt $width;$x++){
                $i=$offset+3*($y*$width+$x)
                $bitmap.SetPixel($x,$y,[Drawing.Color]::FromArgb($pixels[$i],$pixels[$i+1],$pixels[$i+2]))
            }}
            $bitmap.Save("$PSScriptRoot/build/orquestador-metal.png",[Drawing.Imaging.ImageFormat]::Png)
        }
        finally {$bitmap.Dispose()}
    }
    # Llenar mas de 25 filas y comprobar el desplazamiento y el cursor real.
    for($i=0;$i -lt 30;$i++) {Send-Monitor 'sendkey h 10';Start-Sleep -Milliseconds 40}
    Send-Monitor 'sendkey o 10'
    Start-Sleep -Milliseconds 80
    Send-Monitor "pmemsave 0xb8000 4000 $base-scroll.bin"
    Send-Monitor "pmemsave 0x9020 16 $base-state.bin"
    do {
        if($timer.Elapsed.TotalSeconds -gt 30){throw 'No se guardo el resultado del desplazamiento.'}
        Start-Sleep -Milliseconds 20
    } until((Test-Path $statePath) -and (Test-Path $scrollVram) -and (Get-Item $statePath).Length -eq 16 -and (Get-Item $scrollVram).Length -eq 4000)
    $state=[IO.File]::ReadAllBytes($statePath)
    $after=[IO.File]::ReadAllBytes($scrollVram)
    for($i=0;$i -lt 2000;$i++){$characters[$i]=$after[$i*2]}
    $afterText=[Text.Encoding]::ASCII.GetString($characters)
    if([BitConverter]::ToUInt32($state,0) -ge 2000 -or $afterText.Contains('Orquestador del Metal') -or -not $afterText.Contains('Hola mundo desde mi .hex!')) {
        throw 'El desplazamiento no conservo los limites o el texto esperado.'
    }
    Send-Monitor 'sendkey q 10'
    Wait-Serial 'GREEN [halt] stopped'
    $trace=Read-Shared "$PSScriptRoot/$base-instructions.log"
    if($trace -match 'check_exception|Triple fault'){throw 'Fallo de CPU en pantalla/teclado.'}
    $debug=Read-Shared "$PSScriptRoot/$base-debug.log"
    if($debug -match '\[PS2\]' -or (-not $InjectCursorFault -and $debug -match '\[VGA\]')){throw "Guardian de pantalla/teclado activado inesperadamente: $debug"}
    if($InjectCursorFault -and -not $debug.Contains('YELLOW [VGA] cursor invalid; reset')){throw 'El guardian no explico la recuperacion del cursor.'}
    @{Passed=1;Total=1;Checks='PS2 Shift, texto, borrado, Enter, Escape, VGA, scroll, cursor y CPU';Capture='orquestador-metal.ppm'} |
        ConvertTo-Json | Set-Content "$base-results.json"
    Write-Host 'OK: pantalla VGA y teclado PS/2 propios; hola, eco, Shift, borrado, Enter y Escape.'
}
finally {
    if($process){
        if(-not $process.HasExited){$process.Kill();$process.WaitForExit()}
        if($stderr){$stderr.GetAwaiter().GetResult() | Set-Content "$base-error.log"}
        if($stdout){$stdout.GetAwaiter().GetResult() | Set-Content "$base-monitor.log"}
        $process.Dispose()
    }
    Pop-Location
}
