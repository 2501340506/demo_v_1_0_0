param([string]$RunName='adjust_gate1',[string]$SynthesisName='adjust_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
$sim='D:/modelsim/win64'
foreach($module in @('brightness_contrast_adjust','pcm_master_volume')) {
 $work=Join-Path $out $module
 New-Item -ItemType Directory -Path $work | Out-Null
 $syn="$root/diagnostics/output/$SynthesisName/$module".Replace('\','/')
 $unix=$work.Replace('\','/')
 $tcl=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$syn/demo.prj} -noanalyze
import_db {$syn/demo_gate.db}
write_verilog {$unix/gate.v}
exit
"@
 [IO.File]::WriteAllText("$work/export.tcl",$tcl)
 Push-Location $work
 try { & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe "$unix/export.tcl" *> "$work/export.log" } finally { Pop-Location }
 if(!(Test-Path "$work/gate.v")){throw 'Gate export failed'}
 $lib="$unix/work"
 & "$sim/vlib.exe" $lib *> "$work/library.log"
 $vendor=Get-ChildItem 'D:/TD/anlogic/TD6.2.1/sim_release/eg4/*.v','D:/TD/anlogic/TD6.2.1/sim_release/common/*.v' | ForEach-Object {$_.FullName}
 & "$sim/vlog.exe" -work $lib @vendor "$work/gate.v" *> "$work/vendor.log"
 if($LASTEXITCODE){throw 'Gate compile failed'}
 # The standalone picture synthesis uses SIDE_WIDTH=1, so test a one-bit tag.
 $bench=(Get-Content "$PSScriptRoot/tb_adjust.sv" -Raw).Replace('#(.SIDE_WIDTH(16))','').Replace('[15:0] tag','[0:0] tag').Replace('[15:0] result_tag','[0:0] result_tag').Replace('[15:0] tags','[0:0] tags')
 [IO.File]::WriteAllText("$work/bench.sv",$bench)
 & "$sim/vlog.exe" -sv -work $lib "$work/bench.sv" *> "$work/compile.log"
 if($LASTEXITCODE){throw 'Bench compile failed'}
 $test=if($module -eq 'pcm_master_volume'){'tb_volume'}else{'tb_adjust'}
 & "$sim/vsim.exe" -c -quiet -lib $lib $test glbl -l "$work/gate.log" -do 'run -all; quit -f' *> "$work/console.log"
 $log=Get-Content "$work/gate.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ') {throw "Gate test failed: $module"}
 Write-Output "PASS synthesized arithmetic $module"
}
