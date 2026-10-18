param([string]$RunName='disaster_s2_audio_control_equivalence01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/scene/scenario_audio_control.v" "$PSScriptRoot/tb_audio_control_equivalence.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_audio_control_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content -Raw "$out/sim.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS audio control equivalence'){throw 'Equivalence failed'}
 Write-Output 'PASS audio control equivalence'
}finally{Pop-Location}
