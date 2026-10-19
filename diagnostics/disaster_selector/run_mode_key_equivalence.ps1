param([string]$RunName='fast_key_equivalence01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/mode_key_control.v" "$root/user_source/hdl_source/SD/key_press_debounce.v" "$PSScriptRoot/mode_key_control_reference.v" "$PSScriptRoot/tb_mode_key_equivalence.sv" "$root/diagnostics/publicity_mode/tb_m3_keys.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_mode_key_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content -Raw "$out/sim.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS mode key equivalence') {throw 'Equivalence failed'}
 Write-Output 'PASS mode key equivalence'
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_m3_keys -l "$out/keys.log" -do 'run -all; quit -f' *> "$out/keys.console.log"
 $log=Get-Content -Raw "$out/keys.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M3 keys') {throw 'Directed gestures failed'}
 Write-Output 'PASS directed M3 keys' 
}finally{Pop-Location}
