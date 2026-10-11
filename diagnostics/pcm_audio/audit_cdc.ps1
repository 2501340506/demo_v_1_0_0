param([Parameter(Mandatory=$true)][string]$BuildName)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName/pcm_cdc_audit"
$run=(Join-Path $root "diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1").Replace('\','/')
New-Item -ItemType Directory -Path $out -Force | Out-Null
$script=@'
import_device eagle_s20.db -package EG4S20BG256
open_project {PROJECT_PATH/demo.prj} -noanalyze
import_db {PROJECT_PATH/demo_pr.db}
update_timing -mode final
report_timing_path -from [get_clocks {sd_card_clk video_clk}] -to [get_clocks {sd_card_clk video_clk}] -ep_num 60 -path_num 2 -file pcm_cdc.timing
write_verilog routed.v
exit
'@
$script=$script.Replace('PROJECT_PATH',$run)
[IO.File]::WriteAllText("$out/audit.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $out
try {
 & 'D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe' "$($out.Replace('\','/'))/audit.tcl" *> "$out/console.log"
 if($LASTEXITCODE -or !(Test-Path "$out/pcm_cdc.timing")){throw 'PCM CDC audit failed'}
 Write-Output "PCM CDC audit: $out/pcm_cdc.timing"
}finally{Pop-Location}
