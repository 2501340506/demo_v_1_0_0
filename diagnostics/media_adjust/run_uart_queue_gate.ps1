param([string]$RunName='adjust_queue_gate1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$unix=$out.Replace('\','/')
$wrapper=@'
module logger_gate_top(
 input clk,rst,input [15:0] events,input [1:0] image_index,
 input [31:0] sector,input [2:0] error_code,input [3:0] phase,
 input auto_enabled,input [63:0] sd_debug,output uart_tx,
 input reply_valid,input [7:0] reply_data,input reply_last,output reply_ready);
 uart_event_logger #(.CLK_FREQ_HZ(100000),.BAUD_RATE(10000),.QUEUE_DEPTH(2)) impl(
 .clk(clk),.rst(rst),.events(events),.image_index(image_index),.sector(sector),
 .error_code(error_code),.phase(phase),.auto_enabled(auto_enabled),.sd_debug(sd_debug),
 .uart_tx(uart_tx),.reply_valid(reply_valid),.reply_data(reply_data),.reply_last(reply_last),.reply_ready(reply_ready));
endmodule
'@
[IO.File]::WriteAllText("$out/wrapper.v",$wrapper)
Copy-Item "$root/user_source/hdl_source/uart/uart_event_logger.v" "$out/uart_event_logger.v"
Copy-Item "$root/user_source/hdl_source/uart/uart_tx_byte.v" "$out/uart_tx_byte.v"
[xml]$xml=(Get-Content "$root/TD_project/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
$entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
$xml.Project.Source_Files.RemoveAll();$verilog=$xml.CreateElement('Verilog');$order=0
foreach($name in @('wrapper.v','uart_event_logger.v','uart_tx_byte.v')){
 $file=$entry.CloneNode($true);$file.SetAttribute('Path',"$unix/$name")
 $file.SelectSingleNode("FileInfo/Attr[@Name='CompileOrder']").SetAttribute('Val',[string]$order);$order++
 [void]$verilog.AppendChild($file)
}
[void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
[IO.File]::WriteAllText("$out/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'))
$settings=@'
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {logger_gate_top}
set run_type syn
set start_step read_design
set end_step opt_gate
'@
[IO.File]::WriteAllText("$out/settings.cfg",$settings)
Push-Location $out
try {
 & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> "$out/build.log"
 if($LASTEXITCODE -or (Get-Content "$out/build.log" -Raw) -match '(?im)\bERROR:'){throw 'Synthesis failed'}
 $tcl="import_device eagle_s20.db -package EG4S20BG256`nopen_project {$unix/demo.prj} -noanalyze`nimport_db {$unix/demo_gate.db}`nwrite_verilog {$unix/gate.v}`nexit`n"
 [IO.File]::WriteAllText("$out/export.tcl",$tcl)
 & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe "$unix/export.tcl" *> "$out/export.log"
 if($LASTEXITCODE -or !(Test-Path "$out/gate.v")){throw 'Export failed'}
 $bench=Get-Content "$root/diagnostics/uart_fastboot/tb_uart_event_logger.sv" -Raw
 $bench=[regex]::Replace($bench,'uart_event_logger #\(.*?\) dut\(','logger_gate_top dut(')
 $bench=$bench.Replace('#27 rst=0;','#2027 rst=0;')
 [IO.File]::WriteAllText("$out/bench.sv",$bench)
 $sim='D:/modelsim/win64';$lib="$unix/work"
 & "$sim/vlib.exe" $lib *> "$out/library.log"
 $vendor=Get-ChildItem D:/TD/anlogic/TD6.2.1/sim_release/eg4/*.v,D:/TD/anlogic/TD6.2.1/sim_release/common/*.v | ForEach-Object {$_.FullName}
 & "$sim/vlog.exe" -work $lib @vendor "$out/gate.v" *> "$out/vendor.log"
 if($LASTEXITCODE){throw 'Gate compile failed'}
 & "$sim/vlog.exe" -sv -work $lib "$out/bench.sv" *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Bench compile failed'}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_uart_event_logger glbl -l "$out/gate.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/gate.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS tb_uart_event_logger'){throw 'Gate simulation failed'}
 Write-Output 'PASS TD synthesized BRAM UART: exact serial bytes, snapshot, DROP, simultaneous events and cache messages'
}finally{Pop-Location}
