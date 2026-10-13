param([string]$RunName='adjust_reply_fields1',[string]$SourceRoot='')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(!$SourceRoot){$SourceRoot=$root}
$SourceRoot=(Resolve-Path $SourceRoot).Path
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show '1c0efbb:user_source/hdl_source/uart/subtitle_uart_controller.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-change subtitle controller'}
$reference=$reference -replace '\bmodule subtitle_uart_controller\b','module subtitle_uart_controller_reference'
[IO.File]::WriteAllText("$out/reference.v",$reference)
$bench=Get-Content "$root/diagnostics/osd/tb_uart_subtitle.sv" -Raw
$outputs=@('cfg_text','cfg_length','cfg_enable','cfg_update_valid','reply_valid','reply_data','reply_last')
$instance=[regex]::Match($bench,'(?s) subtitle_uart_controller control\(.*?;').Value
$instance=$instance.Replace('subtitle_uart_controller control(','subtitle_uart_controller_reference reference_control(')
foreach($port in $outputs){$instance=[regex]::Replace($instance,"\.$port\([^)]*\)",".$port()")}
$lhs=($outputs | ForEach-Object {"control.$_"}) -join ','
$rhs=($outputs | ForEach-Object {"reference_control.$_"}) -join ','
$check="`n$instance`n always @(posedge clk) begin #1;if(!rst && {$lhs} !== {$rhs})`n `$fatal(1,`"subtitle cycle equivalence mismatch`");end`n"
[IO.File]::WriteAllText("$out/integration.sv",$bench.Replace('endmodule',"$check`nendmodule"))
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$osd=@('osd_pixel_position','osd_font_5x7','osd_font_cn_16x16','scroll_text_overlay','osd_alpha_band','subtitle_frame_commit') | ForEach-Object {"$root/user_source/hdl_source/osd/$_.v"}
$uart=@('uart_rx_byte','uart_tx_byte','uart_event_logger','subtitle_uart_controller') | ForEach-Object {"$SourceRoot/user_source/hdl_source/uart/$_.v"}
& "$sim/vlog.exe" -sv -work $lib @osd @uart "$out/reference.v" "$PSScriptRoot/tb_subtitle_fields.sv" "$out/integration.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try {
 foreach($test in @('tb_subtitle_fields','tb_uart_subtitle')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $rc=$LASTEXITCODE;$log=Get-Content "$out/$test.log" -Raw
  if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $test"}
  Write-Output "PASS $test (old/new equivalent)"
 }
}finally{Pop-Location}
