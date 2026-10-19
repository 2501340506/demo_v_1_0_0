param([Parameter(Mandatory=$true)][ValidateSet('fast_start_td23','page_error_diag_td01')][string]$BuildName,
      [string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/page_candidate_comparison01/$BuildName"
$run="$root/diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1"
if(Test-Path "$out/interface.log"){throw 'Comparison output already exists'}
New-Item -ItemType Directory -Force $out | Out-Null
# Read existing placed/routed databases; no synthesis, route, or bit generation.
$script=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$run/demo.prj} -noanalyze
import_db {$run/demo_pr.db}
update_timing -mode final
report_timing_path -from [get_ports sd_miso] -ep_num 10 -path_num 1 -file miso_setup.timing
report_timing_path -to [get_ports {sd_dclk sd_mosi sd_ncs}] -ep_num 10 -path_num 1 -file spi_outputs.timing
exit
"@
[IO.File]::WriteAllText("$out/interface.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $out
try {
 & "$TdRoot/bin/td_commands_prompt.exe" "$out/interface.tcl" *> "$out/interface.log"
 if($LASTEXITCODE -or !(Test-Path "$out/miso_setup.timing") -or !(Test-Path "$out/spi_outputs.timing")) {
  throw "Interface audit failed; inspect $out/interface.log"
 }
 Write-Output "Interface timing: $out"
}finally{Pop-Location}
