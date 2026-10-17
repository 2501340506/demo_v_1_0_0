param([string]$RunName='uart_reduction_constraints01',[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sdc=Get-Content -Raw -Encoding UTF8 "$root/user_source/constraints_source/timing.sdc"
[IO.File]::WriteAllText("$out/enabled.sdc",$sdc.Replace('# UART_TX_ON ','').Replace('# UART_RX_ON ',''),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText("$out/disabled.sdc",$sdc,[Text.UTF8Encoding]::new($false))
foreach($case in @(@{Name='enabled';Build='publicity_m5_td_attempt27'},@{Name='disabled';Build='uart_reduction_td_attempt01'})){
 $run="$root/diagnostics/output/$($case.Build)/TD_project/demo_Runs/phy_1"
 $script=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$run/demo.prj} -noanalyze
import_db {$run/demo_pr.db}
clear_sdc
read_sdc {$out/$($case.Name).sdc}
update_timing -mode final
report_timing_summary -file $($case.Name).timing
report_timing_exception -ep_num 1 -path_num 1 -file $($case.Name).exceptions
puts "UART_LOG_COUNT=[llength [get_cells -hier -quiet {*u_uart_logger*}]]"
exit
"@
 [IO.File]::WriteAllText("$out/$($case.Name).tcl",$script,[Text.UTF8Encoding]::new($false))
 Push-Location $out
 try {
  & "$TdRoot/bin/td_commands_prompt.exe" "$out/$($case.Name).tcl" *> "$out/$($case.Name).log"
  if($LASTEXITCODE){throw "Constraint probe failed: $($case.Name)"}
 }finally{Pop-Location}
}
& py -I -X utf8 "$PSScriptRoot/verify_constraints.py" $out
if($LASTEXITCODE){throw 'Constraint probe verification failed'}
