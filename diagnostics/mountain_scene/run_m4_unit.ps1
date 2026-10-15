param([string]$RunName='mountain_m4_unit01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=@('scene/scenario_fsm.v','scene/scenario_audio_control.v','scene/scene_event_cdc.v','scene/scenario_frame.v','adjust/pcm_master_volume.v','SD/mode_key_control.v','SD/key_press_debounce.v','SD/fat32_volume_scanner.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
$benches=@('tb_scenario','tb_scenario_cdc','tb_scene_fade','tb_scene_keys','tb_snd_scan')
$files=$benches | ForEach-Object {"$PSScriptRoot/$_.sv"}
& "$sim/vlog.exe" -sv -work $lib @rtl @files *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out"}
foreach($test in $benches){
 & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/${test}_console.log"
 $log=Get-Content "$out/$test.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning)' -or $log -notmatch 'PASS M4' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed $test : $out"}
 Write-Output "PASS $test : $out/$test.log"
}
