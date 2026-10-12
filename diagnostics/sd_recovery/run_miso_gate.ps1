param([Parameter(Mandatory=$true)][string]$BuildName,[Parameter(Mandatory=$true)][string]$RunName)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$run=Join-Path $root "diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1"
$export=Join-Path $root "diagnostics/output/$BuildName/miso_gate_export"
New-Item -ItemType Directory -Path $export -ErrorAction Stop | Out-Null
$run=$run.Replace('\','/');$export=$export.Replace('\','/')
$script=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$run/demo.prj} -noanalyze
import_db {$run/demo_pr.db}
write_verilog {$export/routed.v}
exit
"@
[IO.File]::WriteAllText("$export/export.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $export
try {
 & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe "$export/export.tcl" *> "$export/export.log"
 if($LASTEXITCODE){throw 'Routed export failed'}
}finally{Pop-Location}
& python "$PSScriptRoot/check_miso_gate.py" "$export/routed.v" $RunName
if($LASTEXITCODE){throw 'Routed MISO gate check failed'}
