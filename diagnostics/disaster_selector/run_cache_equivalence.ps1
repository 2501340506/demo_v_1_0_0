param([string]$RunName='disaster_s2_cache_equivalence01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/media_frame_cache_control.v" "$PSScriptRoot/media_frame_cache_control_reference.v" "$PSScriptRoot/tb_cache_equivalence.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_cache_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content -Raw "$out/sim.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS cache equivalence') {throw 'Equivalence failed'}
 Write-Output 'PASS cache equivalence'
}finally{Pop-Location}
