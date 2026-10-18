param([string]$RunName='disaster_s1_layers01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "E:/TD/sim_release/common/al_map_lut.v" "$root/user_source/hdl_source/scene/hazard_layer.v" "$root/user_source/hdl_source/scene/hazard_layer_v3.v" "$root/user_source/hdl_source/scene/disaster_layer.v" "$PSScriptRoot/tb_m3v3_card.sv" "$PSScriptRoot/tb_m3v3_sweep.sv" "$PSScriptRoot/tb_disaster_layer.sv" "$PSScriptRoot/tb_hash8.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
foreach($test in @('tb_hash8','tb_disaster_layer','tb_m3v3_sweep','tb_m3v3_card')){
 & "$sim/vsim.exe" -c -quiet -lib $lib $test "-gVEC_DIR=$root/diagnostics/output/disaster_s1_vectors01/vectors" -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
 $log=Get-Content -Raw "$out/$test.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS '){throw "Failed $test"}
 Write-Output "PASS $test"
}
