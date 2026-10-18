# Conservative cleanup of regenerable artifacts; preview unless -Apply is supplied.
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Apply)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')+'\'
$targets=[Collections.Generic.List[string]]::new()
foreach($relative in @('__pycache__','CASM/__pycache__')){
    $candidate=Join-Path $root $relative
    if(Test-Path -LiteralPath $candidate){$targets.Add($candidate)}
}
$oldExamples=Join-Path $root 'CASM/ejemplos'
if((Test-Path -LiteralPath $oldExamples) -and @(Get-ChildItem -LiteralPath $oldExamples -Force).Count -eq 0){$targets.Add($oldExamples)}
# Keep the newest successful run. Remove older runs only if all five files match it.
$runs=@(Get-ChildItem -LiteralPath (Join-Path $root 'build/CASM') -Directory -ErrorAction SilentlyContinue |
    Where-Object {$_.Name -match '^run-[0-9a-f]{32}$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'verified.json'))} |
    Sort-Object LastWriteTime -Descending)
$runFiles=@('INICIO.X86','program.hex','program.ir.json','source.casm','verified.json')
if($runs.Count -gt 1){
    foreach($run in $runs | Select-Object -Skip 1){
        $files=@(Get-ChildItem -LiteralPath $run.FullName -Force)
        $same=$files.Count -eq $runFiles.Count
        foreach($name in $runFiles){
            $older=Join-Path $run.FullName $name
            $newer=Join-Path $runs[0].FullName $name
            if(-not(Test-Path -LiteralPath $older -PathType Leaf) -or -not(Test-Path -LiteralPath $newer -PathType Leaf)){$same=$false;break}
            if((Get-FileHash -LiteralPath $older).Hash -cne (Get-FileHash -LiteralPath $newer).Hash){$same=$false;break}
        }
        if($same){$targets.Add($run.FullName)}
    }
}
# Only negative-test image copies; preserve the normal virtual image and all evidence.
foreach($case in @('firma','suma','ausente','excesivo','entrada','salida')){
    foreach($suffix in @('.img','-vars.fd')){
        $candidate=Join-Path $root "build/puente-$case$suffix"
        if(Test-Path -LiteralPath $candidate -PathType Leaf){$targets.Add($candidate)}
    }
}
$records=@()
foreach($target in $targets){
    $absolute=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $target).Path)
    if(-not $absolute.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw "Cleanup target outside workspace: $absolute"}
    $item=Get-Item -LiteralPath $absolute -Force
    $children=if($item.PSIsContainer){@(Get-ChildItem -LiteralPath $absolute -Recurse -Force)}else{@()}
    if(@(@($item)+$children | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw "Cleanup refuses reparse points: $absolute"}
    $bytes=if($item.PSIsContainer){($children | Where-Object {-not $_.PSIsContainer} | Measure-Object Length -Sum).Sum}else{$item.Length}
    if($null -eq $bytes){$bytes=0}
    $relative=$absolute.Substring($root.Length)
    $removed=$false
    if($Apply -and $PSCmdlet.ShouldProcess($absolute,'Remove regenerable artifact')){
        Remove-Item -LiteralPath $absolute -Recurse -Force
        $removed=$true
    }
    $records+=[pscustomobject][ordered]@{Path=$relative;Bytes=$bytes;Removed=$removed}
}
$total=($records | Measure-Object Bytes -Sum).Sum
if($null -eq $total){$total=0}
$records | ForEach-Object {Write-Host ("{0}: {1} bytes; removed={2}" -f $_.Path,$_.Bytes,$_.Removed)}
if($Apply){
    [ordered]@{Scope='Regenerable artifacts only';Applied=$true;Candidates=$records;CandidateBytes=$total} |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'build/cleanup-last.json') -Encoding utf8
}
Write-Host ("Cleanup candidates: {0}; {1:N2} MiB. Apply={2}" -f $records.Count,($total/1MB),[bool]$Apply)
