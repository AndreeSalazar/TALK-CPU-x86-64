param([switch]$Comprobar,[switch]$Estatico)
& "$PSScriptRoot/Games/Flappy_Metal/run.ps1" -Check:$Comprobar -Static:$Estatico
