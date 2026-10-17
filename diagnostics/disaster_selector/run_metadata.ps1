param([string]$RunName='disaster_s1_metadata01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I -X utf8 "$PSScriptRoot/prepare_metadata.py" $out
if($LASTEXITCODE){throw 'prepare failed'}
# Reuse the freshly compiled production library, only add a new test module.
$sim='F:/modelsim/win64';$lib="$root/diagnostics/output/disaster_s1_unit02/work"
& "$sim/vlog.exe" -sv -work $lib "$out/tb_disaster_metadata.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
foreach($case in @(0,5,7,8,9)){
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_disaster_metadata glbl "-gCARD_CASE=$case" -l "$out/case$case.log" -do 'run -all; quit -f' *> "$out/case$case.console.log"
 $log=Get-Content -Raw "$out/case$case.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS disaster metadata'){throw "Failed case $case"}
 Write-Output "PASS metadata case $case"
}
