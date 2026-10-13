# run_uart_fields.ps1 with the formatter check reading the effective character:
# ROM positions take text_rom[{text_sel,char_index}], the rest tx_data.
param([string]$RunName='lut_uart_rom_fields1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show 'f5ede4e:user_source/hdl_source/uart/uart_event_logger.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-optimization reference'}
$reference=$reference -replace '\bmodule uart_event_logger\b','module uart_event_logger_reference'
[IO.File]::WriteAllText("$out/uart_event_logger_reference.v",$reference,[Text.UTF8Encoding]::new($false))
$fields=Get-Content "$root/diagnostics/media_adjust/tb_uart_field_equivalence.sv" -Raw
$effective='{dut.tx_hex,(dut.text_char ? dut.text_rom[{dut.text_sel,dut.char_index[4:0]}] : dut.tx_data)}'
$count=([regex]::Matches($fields,[regex]::Escape('{dut.tx_hex,dut.tx_data}'))).Count
if($count -ne 2){throw "Expected 2 formatter references, found $count"}
[IO.File]::WriteAllText("$out/tb_uart_field_equivalence.sv",$fields.Replace('{dut.tx_hex,dut.tx_data}',$effective))
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/uart/uart_tx_byte.v" "$root/user_source/hdl_source/uart/uart_event_logger.v" "$out/uart_event_logger_reference.v" "$out/tb_uart_field_equivalence.sv" "$root/diagnostics/media_adjust/tb_uart_queue.sv" "$root/diagnostics/uart_fastboot/tb_uart_event_logger.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try {
 foreach($test in @('tb_uart_field_equivalence','tb_uart_event_logger','tb_uart_queue')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $rc=$LASTEXITCODE;$log=Get-Content "$out/$test.log" -Raw
  if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
