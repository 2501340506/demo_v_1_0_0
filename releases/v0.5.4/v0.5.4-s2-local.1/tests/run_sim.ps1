param([string]$RunName='v054_s1_uart')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$lib=(Join-Path $out 'work').Replace('\','/')
if (-not (Test-Path "$lib/_info")) { & "$sim/vlib.exe" $lib }
& "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" "$root/user_source/hdl_source/uart/uart_tx_byte.v" "$root/user_source/hdl_source/uart/uart_boot_reporter.v" "$root/user_source/hdl_source/uart/uart_event_logger.v" "$PSScriptRoot/tb_uart_boot.sv" "$PSScriptRoot/tb_uart_event_logger.sv"
if($LASTEXITCODE){throw 'UART compile failed'}
foreach($tb in @('tb_uart_boot','tb_uart_event_logger')) {
  & "$sim/vsim.exe" -c -lib $lib $tb -l "$out/${tb}.log" -do 'run -all; quit -f'
  if($LASTEXITCODE){throw "UART simulation failed: $tb"}
  $log=Get-Content "$out/${tb}.log" -Raw
  if($log -notmatch 'PASS ' -or $log -match '\*\* (Error|Fatal):'){throw "UART evidence failed: $tb"}
}
Write-Output 'PASS UART S1'
