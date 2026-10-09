param([string]$RunName='four_bank_s2_control1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName to preserve evidence'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64'
$lib=(Join-Path $out 'work').Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/media_frame_cache_control.v" "$root/user_source/hdl_source/SD/media_player_control.v" "$PSScriptRoot/tb_frame_cache_control.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_frame_cache_control -l "$out/simulation.log" -do 'run -all; quit -f' *> "$out/console.log"
$rc=$LASTEXITCODE
$log=Get-Content "$out/simulation.log" -Raw
if($rc -ne 0 -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS frame cache control:' -or $log -notmatch 'Errors: 0,'){
    throw "Cache controller simulation failed: $out/simulation.log"
}
Write-Output "PASS cache controller simulation: $out/simulation.log"
