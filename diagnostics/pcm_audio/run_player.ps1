param([string]$RunName='pcm_s2_player_exact1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location $root
try {
 & "$sim/vlog.exe" -sv -work $lib user_source/hdl_source/audio/pcm_stream_player.v diagnostics/pcm_audio/tb_pcm_stream_player.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_pcm_stream_player -l "$out/player.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$x=Get-Content "$out/player.log" -Raw
 if($rc -or $x -notmatch 'PASS PCM player:' -or $x -match '\*\* (Fatal|Error|Warning)' -or $x -notmatch 'Errors: 0, Warnings: 0'){throw "player test failed: $out/player.log"}
 Write-Output "PASS PCM player: $out/player.log"
}finally{Pop-Location}
