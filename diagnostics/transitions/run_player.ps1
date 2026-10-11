param([string]$RunName='transition_s1_player1')
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
 & "$sim/vlog.exe" -sv -work $lib user_source/hdl_source/video_transition_control.v user_source/hdl_source/video_transition_sd_control.v user_source/hdl_source/video_transition_pixels.v user_source/hdl_source/SD/media_player_control.v diagnostics/transitions/tb_transition_player.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_transition_player -l "$out/unit.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/unit.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS transition player:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw 'Unit test failed'}
 Write-Output "PASS transition unit: $out/unit.log"
}finally{Pop-Location}
