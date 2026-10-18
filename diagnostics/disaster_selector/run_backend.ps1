param([string]$RunName='disaster_menu_backend01')
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../output/$RunName"))
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$PSScriptRoot/../../user_source/hdl_source/scene/disaster_menu_backend.v" "$PSScriptRoot/tb_menu_backend.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_menu_backend -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
$log=Get-Content -Raw "$out/sim.log"
if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS menu backend:'){throw "FAIL $out"}
Write-Output 'PASS menu backend'
