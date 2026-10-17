param([Parameter(Mandatory=$true)][string]$BuildName,[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
& "$root/diagnostics/publicity_mode/run_m4_audit.ps1" -BuildName $BuildName -TdRoot $TdRoot
$out="$root/diagnostics/output/$BuildName/timing_audit"
$run="$root/diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1"
$script=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$run/demo.prj} -noanalyze
import_db {$run/demo_pr.db}
update_timing -mode final
report_timing_exception -ep_num 30 -path_num 1 -file exceptions.timing
puts "UART_LOG_COUNT=[llength [get_cells -hier -quiet {*u_uart_logger*}]]"
exit
"@
[IO.File]::WriteAllText("$out/exceptions.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $out
try {
 & "$TdRoot/bin/td_commands_prompt.exe" "$out/exceptions.tcl" *> "$out/exceptions.log"
 if($LASTEXITCODE -or !(Test-Path "$out/exceptions.timing")){throw 'Exception audit failed'}
 Write-Output "Exception audit: $out/exceptions.timing"
}finally{Pop-Location}
