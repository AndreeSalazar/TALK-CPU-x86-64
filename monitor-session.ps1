param([string]$Qemu, [switch]$Check)
$ErrorActionPreference='Stop'
$base='build/faggin-64-monitor'
$arguments=@('-machine','pc','-cpu','qemu64','-accel','tcg','-m','16M','-smp','1',
    '-bios',"$base.rom",'-nodefaults','-display','none','-monitor','none',
    '-serial','stdio','-chardev',"file,id=debug,path=$base-debug.log",
    '-device','isa-debugcon,iobase=0xe9,chardev=debug','-no-reboot')
if (-not $Check) {
    Write-Host 'Monitor: h ayuda, s estado, a reservar 256 bytes, q detener. Ctrl+C sale de QEMU.'
    & $Qemu @arguments
    if ($LASTEXITCODE -ne 0) { throw "QEMU termino con codigo $LASTEXITCODE" }
    return
}
$arguments+=@('-d','in_asm,int','-D',"$base-instructions.log")
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$Qemu
$start.Arguments=$arguments -join ' '
$start.WorkingDirectory=$PSScriptRoot
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
        @{Command='';Expected='Faggin monitor64 READY'},
        @{Command='h';Expected='h help | s status | a alloc256 | q halt'},
        @{Command='s';Expected='GREEN [64] cursor=0000000000100000 latch=0000000000000000'},
        @{Command='a';Expected='GREEN [alloc256] ptr=0000000000100000'},
        @{Command='a';Expected='GREEN [alloc256] ptr=0000000000100100'},
        @{Command='s';Expected='GREEN [64] cursor=0000000000100200 latch=0000000000000000'},
        @{Command='?';Expected='YELLOW [command] unknown; press h'},
        @{Command='q';Expected='GREEN [halt] stopped'}
    )
    foreach ($step in $steps) {
        if ($step.Command) { $process.StandardInput.Write($step.Command); $process.StandardInput.Flush() }
        $pending=$process.StandardOutput.ReadLineAsync()
        while (-not $pending.IsCompleted) {
            if ($process.HasExited -or $timer.Elapsed.TotalSeconds -gt 30) { throw 'El monitor no respondio en el plazo esperado.' }
            Start-Sleep -Milliseconds 20
        }
        $line=$pending.GetAwaiter().GetResult()
        $transcript.Add($line)
        if ($line -cne $step.Expected) { throw "Respuesta incorrecta: esperado '$($step.Expected)', recibido '$line'" }
    }
    # Esperar la instruccion HLT, no solo el texto anterior a ella.
    do {
        $stream=[IO.File]::Open("$PSScriptRoot/$base-instructions.log",'Open','Read','ReadWrite')
        $reader=[IO.StreamReader]::new($stream)
        try { $trace=$reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($trace -match 'Triple fault|check_exception') { throw 'Fallo inesperado de CPU en el monitor.' }
        if ($timer.Elapsed.TotalSeconds -gt 30) { throw 'No se confirmo HLT del monitor.' }
        Start-Sleep -Milliseconds 20
    } until ($trace -match '0x000f328b:\s+f4\s+hlt')
    $debug=Get-Content "$PSScriptRoot/$base-debug.log" -Raw
    $expected="Faggin scaling: 16 bits OK`r`nFaggin scaling: 32 bits OK`r`nFaggin scaling: 64 bits OK`r`nGREEN [CPU] guardians active`r`nGREEN [Memory] integrity latch OK`r`nGREEN [Memory] bounded allocator OK`r`n"
    if ($debug -cne $expected) { throw 'El monitor no completo todas las autopruebas previas.' }
    Write-Host 'OK: consola propia de 64 bits, estado, dos reservas, rechazo de orden y parada.'
}
finally {
    if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $transcript | Set-Content "$PSScriptRoot/$base-console.log"
    if ($errors) { $errors.GetAwaiter().GetResult() | Set-Content "$PSScriptRoot/$base-error.log" }
    $process.Dispose()
}
