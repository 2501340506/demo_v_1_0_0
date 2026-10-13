param([string]$RunName='adjust_reply_pipeline1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show 'b5b48c9:user_source/hdl_source/uart/subtitle_uart_controller.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-change subtitle controller'}
[IO.File]::WriteAllText("$out/reference.v",$reference.Replace('module subtitle_uart_controller(','module subtitle_uart_controller_reference('))
$fields=Get-Content "$PSScriptRoot/tb_subtitle_fields.sv" -Raw
$fields=$fields.Replace('{dut.reply_data,dut.reply_last}',
 '{(dut.reply_hex ? dut.hex(dut.reply_raw[3:0]) : dut.reply_raw),(dut.index==dut.last_index)}')
[IO.File]::WriteAllText("$out/fields.sv",$fields)
$bench=Get-Content "$root/diagnostics/osd/tb_uart_subtitle.sv" -Raw
$outputs=@('cfg_text','cfg_length','cfg_enable','cfg_update_valid','reply_valid','reply_data','reply_last')
$instance=[regex]::Match($bench,'(?s) subtitle_uart_controller control\(.*?;').Value
$instance=$instance.Replace('subtitle_uart_controller control(','subtitle_uart_controller_reference reference_control(')
$instance=$instance.Replace('.reply_ready(reply_ready)','.reply_ready(reply_ready && reply_valid)')
foreach($port in $outputs){$instance=[regex]::Replace($instance,"\.$port\([^)]*\)",".$port()")}
$check=@"
$instance
 always @(posedge clk) begin
  if(!rst && reply_valid && (!reference_control.reply_valid ||
     {reply_data,reply_last} !== {reference_control.reply_data,reference_control.reply_last}))
   `$fatal(1,"prepared reply differs from baseline");
  #1;
  if(!rst && {control.cfg_text,control.cfg_length,control.cfg_enable,control.cfg_update_valid} !==
     {reference_control.cfg_text,reference_control.cfg_length,reference_control.cfg_enable,reference_control.cfg_update_valid})
   `$fatal(1,"configuration cycle mismatch");
 end
"@
[IO.File]::WriteAllText("$out/integration.sv",$bench.Replace('endmodule',"$check`nendmodule"))
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$osd=@('osd_pixel_position','osd_font_5x7','osd_font_cn_16x16','scroll_text_overlay','osd_alpha_band','subtitle_frame_commit') | ForEach-Object {"$root/user_source/hdl_source/osd/$_.v"}
$uart=@('uart_rx_byte','uart_tx_byte','uart_event_logger','subtitle_uart_controller') | ForEach-Object {"$root/user_source/hdl_source/uart/$_.v"}
& "$sim/vlog.exe" -sv -work $lib @osd @uart "$out/reference.v" "$out/fields.sv" "$PSScriptRoot/tb_reply_pipeline.sv" "$out/integration.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try {
 foreach($test in @('tb_subtitle_fields','tb_reply_pipeline','tb_uart_subtitle')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $test"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
