param([string]$RunName='fast_scenario_equivalence01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/scene/scenario_fsm.v" "$PSScriptRoot/scenario_fsm_reference.v" "$PSScriptRoot/tb_scenario_equivalence.sv" "$PSScriptRoot/tb_scenario_thresholds.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_scenario_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content -Raw "$out/sim.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS scenario equivalence') {throw 'Equivalence failed'}
 Write-Output 'PASS scenario equivalence'
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_scenario_thresholds -l "$out/thresholds.log" -do 'run -all; quit -f' *> "$out/thresholds.console.log"
 $log=Get-Content -Raw "$out/thresholds.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M6 scenario') {throw 'Threshold regression failed'}
 Write-Output 'PASS scenario thresholds' 
}finally{Pop-Location}
