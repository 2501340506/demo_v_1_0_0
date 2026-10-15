param([string]$RunName='mountain_m3_unit01',[string]$SimRoot='F:/modelsim/win64')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I "$PSScriptRoot/make_m3_vectors.py" "$out/vectors"
if($LASTEXITCODE){throw 'Vector export failed'}
$lib="$out/work".Replace('\','/')
& "$SimRoot/vlib.exe" $lib *> "$out/library.log"
& "$SimRoot/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/scene/hazard_layer.v" "$root/user_source/hdl_source/scene/scene_demo_timing.v" "$PSScriptRoot/tb_hazard_layer.sv" "$PSScriptRoot/tb_scene_timing.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
foreach($test in @('tb_scene_timing','tb_hazard_layer')){
 $extra=@();if($test -eq 'tb_hazard_layer'){$extra=@("-gVECTOR_DIR=$($out.Replace('\','/'))/vectors")}
 & "$SimRoot/vsim.exe" -c -quiet -lib $lib $test @extra -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/${test}_console.log"
 $log=Get-Content "$out/$test.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning)' -or $log -notmatch 'PASS (hazard layer|scene timing):' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed $test : $out"}
 Write-Output "PASS $test : $out/$test.log"
}
