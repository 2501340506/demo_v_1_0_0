param([string]$RunName='adjust_uart_fields1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show 'f5ede4e:user_source/hdl_source/uart/uart_event_logger.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-optimization reference'}
$reference=$reference -replace '\bmodule uart_event_logger\b','module uart_event_logger_reference'
[IO.File]::WriteAllText("$out/uart_event_logger_reference.v",$reference,[Text.UTF8Encoding]::new($false))
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/uart/uart_tx_byte.v" "$root/user_source/hdl_source/uart/uart_event_logger.v" "$out/uart_event_logger_reference.v" "$PSScriptRoot/tb_uart_field_equivalence.sv" "$root/diagnostics/uart_fastboot/tb_uart_event_logger.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try {
 foreach($test in @('tb_uart_field_equivalence','tb_uart_event_logger')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $rc=$LASTEXITCODE;$log=Get-Content "$out/$test.log" -Raw
  if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
