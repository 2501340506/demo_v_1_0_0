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
report_timing_path -from [get_cells {sw3_syn_4}] -ep_num 5 -path_num 1 -file sw3_sync.timing
write_verilog {$out/physical_audit.v}
puts "SW3_PORT_COUNT=[llength [get_ports sw3]]"
puts "SW3_INPUT_REGISTER_COUNT=[llength [get_cells {sw3_syn_4}]]"
puts "UART_LOG_COUNT=[llength [get_cells -hier -quiet {*u_uart_logger*}]]"
exit
"@
[IO.File]::WriteAllText("$out/exceptions.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $out
try {
 & "$TdRoot/bin/td_commands_prompt.exe" "$out/exceptions.tcl" *> "$out/exceptions.log"
 if($LASTEXITCODE -or !(Test-Path "$out/exceptions.timing")){throw 'Exception audit failed'}
 $log=Get-Content "$out/exceptions.log" -Raw
 if($log -notmatch 'SW3_PORT_COUNT=1' -or $log -notmatch 'SW3_INPUT_REGISTER_COUNT=1'){throw 'SW3 constraint target changed; review netlist'}
 Write-Output "Exception audit: $out/exceptions.timing"
}finally{Pop-Location}
