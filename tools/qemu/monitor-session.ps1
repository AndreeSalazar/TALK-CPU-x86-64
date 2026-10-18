param(
    [string]$Qemu,
    [switch]$Check,
    [switch]$Headless,
    [string]$DiskImage,
    [string[]]$DiskExpected,
    [switch]$AutoStartup,
    [string]$RomPath='build/faggin-64-monitor.rom',
    [string]$LogName,
    [ValidateSet('','magic','size','entry','flags','checksum')]
    [string]$Rejection=''
)
$ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
if (-not $LogName) { $LogName=if ($Check) { 'faggin-64-monitor-check' } else { 'faggin-64-monitor-live' } }
$base="build/$LogName"
$display=if($Check -or $Headless){'none'}else{'gtk'}
$arguments=@('-machine','pc','-cpu','qemu64','-accel','tcg','-m','16M','-smp','1',
    '-bios',$RomPath,'-nodefaults','-device','VGA,addr=2','-display',$display,'-monitor','none',
    '-serial','stdio','-chardev',"file,id=debug,path=$base-debug.log",
    '-device','isa-debugcon,iobase=0xe9,chardev=debug','-no-reboot')
if($DiskImage){$arguments+=@('-drive',"file=$DiskImage,format=raw,if=none,id=metal_disk,snapshot=on",'-device','ide-hd,drive=metal_disk,bus=ide.0,unit=0')}
if (-not $Check) {
    Write-Host 'Orquestador del Metal: h ayuda, o hola, e eco, d disco FAT32, ESC vuelve, q detiene. Ctrl+C sale de QEMU.'
    & $Qemu @arguments -name 'Orquestador del Metal'
    if ($LASTEXITCODE -ne 0) { throw "QEMU termino con codigo $LASTEXITCODE" }
    return
}
$arguments+=@('-d','in_asm,int','-D',"$base-instructions.log")
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$Qemu
$start.Arguments=$arguments -join ' '
$start.WorkingDirectory=$ProjectRoot
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.RedirectStandardInput=$true
$start.RedirectStandardOutput=$true
$start.RedirectStandardError=$true
$process=[Diagnostics.Process]::new()
$process.StartInfo=$start
$transcript=[Collections.Generic.List[string]]::new()
$started=$false
try {
    [void]$process.Start()
    $started=$true
    $errors=$process.StandardError.ReadToEndAsync()
    $timer=[Diagnostics.Stopwatch]::StartNew()
    # Una orden cada vez: no depender del tamano del FIFO UART.
    $steps=@(
        @{Command='';Expected='Orquestador del Metal: listo (64 bits)'},
        @{Command='h';Expected='h help | s status | a alloc256 | o hola | e eco | d disco | q halt'},
        @{Command='s';Expected='GREEN [64] cursor=0000000000100000 latch=0000000000000000'},
        @{Command='a';Expected='GREEN [alloc256] ptr=0000000000100000'},
        @{Command='a';Expected='GREEN [alloc256] ptr=0000000000100100'},
        @{Command='s';Expected='GREEN [64] cursor=0000000000100200 latch=0000000000000000'},
        @{Command='o';Expected='Hola mundo desde mi .hex!'},
        @{Command='e';Expected='ECO64 READY (ESC vuelve)'},
        @{Command='H';Expected='H';Raw=$true},
        @{Command='o';Expected='o';Raw=$true},
        @{Command='l';Expected='l';Raw=$true},
        @{Command='a';Expected='a';Raw=$true},
        @{Command="`b";Expected="`b `b";Raw=$true},
        @{Command='A';Expected='A';Raw=$true},
        @{Command="`n";Expected="`r`n";Raw=$true},
        @{Command=[string][char]27;Expected='ECO64 END'},
        @{Command='o';Expected='Hola mundo desde mi .hex!'},
        @{Command='?';Expected='YELLOW [command] unknown; press h'},
        @{Command='q';Expected='GREEN [halt] stopped'}
    )
    if ($Rejection) {
        $steps=@(
            @{Command='';Expected='Orquestador del Metal: listo (64 bits)'},
            @{Command='o';Expected="RED [load] $Rejection"},
            @{Command='s';Expected='GREEN [64] cursor=0000000000100000 latch=0000000000000000'},
            @{Command='q';Expected='GREEN [halt] stopped'}
        )
    }
    if($DiskExpected){
        $steps=@(@{Command='';Expected='Orquestador del Metal: listo (64 bits)'})
        if($AutoStartup){$steps+=@{Command='';Expected='GREEN [BOOT] search METAL/INICIO.X86'}}
        for($i=0;$i -lt $DiskExpected.Count;$i++){
            $steps+=@{Command=$(if($i -eq 0 -and -not $AutoStartup){'d'}else{''});Expected=$DiskExpected[$i]}
        }
        if($AutoStartup){$steps+=@{Command='';Expected='GREEN [BOOT] monitor available'}}
        $steps+=@(
            @{Command='s';Expected='GREEN [64] cursor=0000000000100000 latch=0000000000000000'},
            @{Command='q';Expected='GREEN [halt] stopped'}
        )
    }
    foreach ($step in $steps) {
        if ($step.Command) { $process.StandardInput.Write($step.Command); $process.StandardInput.Flush() }
        if ($step.Raw) {
            $line=''
            foreach ($expectedCharacter in $step.Expected.ToCharArray()) {
                $buffer=New-Object char[] 1
                $pending=$process.StandardOutput.ReadAsync($buffer,0,1)
                while (-not $pending.IsCompleted) {
                    if ($process.HasExited -or $timer.Elapsed.TotalSeconds -gt 30) { throw 'Eco no respondio en el plazo esperado.' }
                    Start-Sleep -Milliseconds 10
                }
                if ($pending.GetAwaiter().GetResult() -ne 1) { throw 'La salida del eco se cerro.' }
                $line += $buffer[0]
            }
        }
        else {
            $pending=$process.StandardOutput.ReadLineAsync()
            while (-not $pending.IsCompleted) {
                if ($process.HasExited) { throw "QEMU termino: $($errors.GetAwaiter().GetResult())" }
                if ($timer.Elapsed.TotalSeconds -gt 30) { throw 'El monitor no respondio en el plazo esperado.' }
                Start-Sleep -Milliseconds 20
            }
            $line=$pending.GetAwaiter().GetResult()
        }
        $transcript.Add($line)
        if ($line -cne $step.Expected) { throw "Respuesta incorrecta: esperado '$($step.Expected)', recibido '$line'" }
    }
    # Esperar la instruccion HLT, no solo el texto anterior a ella.
    do {
        $stream=[IO.File]::Open("$ProjectRoot/$base-instructions.log",'Open','Read','ReadWrite')
        $reader=[IO.StreamReader]::new($stream)
        try { $trace=$reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($trace -match 'Triple fault|check_exception') { throw 'Fallo inesperado de CPU en el monitor.' }
        if ($timer.Elapsed.TotalSeconds -gt 30) { throw 'No se confirmo HLT del monitor.' }
        Start-Sleep -Milliseconds 20
    } until ($trace -match '0x000f328b:\s+f4\s+hlt')
    if (-not $Rejection -and -not $DiskExpected -and $trace -notmatch '0x00080000:') { throw 'No se confirmo ejecucion del binario desde RAM.' }
    $debug=Get-Content "$ProjectRoot/$base-debug.log" -Raw
    $expected="Faggin scaling: 16 bits OK`r`nFaggin scaling: 32 bits OK`r`nFaggin scaling: 64 bits OK`r`nGREEN [CPU] guardians active`r`nGREEN [Memory] integrity latch OK`r`nGREEN [Memory] bounded allocator OK`r`n"
    if ($debug -cne $expected) { throw 'El monitor no completo todas las autopruebas previas.' }
    Write-Host "OK: $($steps.Count) respuestas exactas del monitor, autopruebas previas y parada sin fallos."
}
finally {
    if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $transcript | Set-Content "$ProjectRoot/$base-console.log"
    if ($errors) { $errors.GetAwaiter().GetResult() | Set-Content "$ProjectRoot/$base-error.log" }
    $process.Dispose()
}
