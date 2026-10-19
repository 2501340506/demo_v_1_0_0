param([string]$RunName='fast_video_equivalence02')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib 'E:/TD/sim_release/common/al_map_lut.v' "$root/user_source/hdl_source/SD/video_delay.v" "$root/diagnostics/lut_reduction/video_delay_ref.v" "$PSScriptRoot/tb_video_equivalence.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_video_equivalence -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/sim.console.log"
$log=Get-Content -Raw "$out/sim.log"
if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS video equivalence'){throw 'Failed video equivalence'}
Write-Output 'PASS video equivalence'
