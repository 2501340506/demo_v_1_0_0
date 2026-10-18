param([string]$RunName='disaster_s2_layer_equivalence01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "E:/TD/sim_release/common/al_map_lut.v" "$root/user_source/hdl_source/scene/hazard_layer.v" "$root/user_source/hdl_source/scene/hazard_layer_v3.v" "$root/user_source/hdl_source/scene/disaster_layer.v" "$PSScriptRoot/disaster_layer_reference.v" "$PSScriptRoot/tb_layer_equivalence.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_layer_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/sim.console.log"
$log=Get-Content -Raw "$out/sim.log"
if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS layer equivalence'){throw 'Failed layer equivalence'}
Write-Output 'PASS layer equivalence'
