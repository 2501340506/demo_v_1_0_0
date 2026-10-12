param([string]$RunName='ring_s2_gate1',[string]$SynthesisName='ring_s1_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$syn="$root/diagnostics/output/$SynthesisName/audio_ring_overlay".Replace('\','/')
$outUnix=$out.Replace('\','/')
$tcl=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$syn/demo.prj} -noanalyze
import_db {$syn/demo_gate.db}
write_verilog {$outUnix/gate.v}
exit
"@
[IO.File]::WriteAllText("$out/export.tcl",$tcl)
Push-Location $out
try { & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe "$outUnix/export.tcl" *> "$out/export.log" }
finally { Pop-Location }
if(!(Test-Path "$out/gate.v")){throw 'Gate export failed'}
$ref=(Get-Content "$root/user_source/hdl_source/audio_vis/audio_ring_overlay.v" -Raw).Replace('module audio_ring_overlay','module ring_overlay_reference')
[IO.File]::WriteAllText("$out/reference.v",$ref)
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'D:/TD/anlogic/TD6.2.1/sim_release/eg4/*.v','D:/TD/anlogic/TD6.2.1/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor "$out/gate.v" *> "$out/vendor_compile.log"
if($LASTEXITCODE){throw 'Vendor/gate compile failed'}
& "$sim/vlog.exe" -sv -work $lib "$out/reference.v" "$root/user_source/hdl_source/audio_vis/audio_ring_rom.v" "$PSScriptRoot/tb_ring_gate.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Gate compile failed'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_ring_gate glbl -l "$out/gate.log" -do 'run -all; quit -f' *> "$out/console.log"
$log=Get-Content "$out/gate.log" -Raw
if($LASTEXITCODE -or $log -notmatch 'PASS synthesized' -or $log -match '\*\* (Fatal|Error):'){throw 'Gate comparison failed'}
Write-Output 'PASS synthesized ring ROM and pipeline'
