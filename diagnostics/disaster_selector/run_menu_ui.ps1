param([string]$RunName='disaster_menu_ui02')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$keys=Get-ChildItem "$root/user_source/hdl_source" -Recurse -Filter '*control.v' | Where-Object { $_.Name -eq 'switch_mode_control.v' }
$debounce=Get-ChildItem "$root/user_source/hdl_source" -Recurse -Filter 'key_press_debounce.v'
& "$sim/vlog.exe" -sv -work $lib $keys.FullName $debounce.FullName "$PSScriptRoot/../../user_source/hdl_source/scene/disaster_menu_control.v" "$PSScriptRoot/tb_menu_control.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_menu_control -l "$out/tb_menu_control.log" -do 'run -all; quit -f' *> "$out/console.log"
$log=Get-Content -Raw "$out/tb_menu_control.log"
if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS menu UI'){throw 'UI test failed'}
Write-Output 'PASS menu UI'
