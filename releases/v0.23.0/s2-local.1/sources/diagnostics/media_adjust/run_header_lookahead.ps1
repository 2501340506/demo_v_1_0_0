param([string]$RunName='adjust_header_lookahead1',[string]$SimRoot='F:/modelsim/win64',[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show '31de2b0:user_source/hdl_source/SD/bmp24_decoder.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-change decoder'}
$reference=$reference.Replace('module bmp24_decoder #(','module bmp24_decoder_reference #(')
[IO.File]::WriteAllText("$out/reference.v",$reference)
$stream=Get-Content "$root/user_source/hdl_source/SD/bmp_scale_stream.v" -Raw
$instance=[regex]::Match($stream,'(?s) bmp24_decoder #\(.*?\);').Value
$instance=$instance.Replace('bmp24_decoder #(','bmp24_decoder_reference #(').Replace(' decoder(',' reference_decoder(')
$instance=$instance -replace ',\s*\.HEADER_OFFSET_LOOKAHEAD\(1\)',''
$outputs=@('header_accepted','pixel_valid','pixel_rgb','pixel_rgba','pixel_x','pixel_y','frame_commit','bmp_done','bmp_error','file_ready','image_width','image_height')
foreach($port in $outputs){$instance=[regex]::Replace($instance,"\.$port\([^)]*\)",".$port()")}
$signals=$outputs+@('declared_size','pixel_offset','width','height','pixel_end','header_ok','header_complete','is_32','row_stride','expected_pixels')
$lhs=($signals | ForEach-Object {"decoder.$_"}) -join ','
$rhs=($signals | ForEach-Object {"reference_decoder.$_"}) -join ','
$check=@"
$instance
 always @(posedge clk) begin
  if(!rst && !file_start && bytes_valid && bytes_ready &&
     decoder.header_byte_offset !== ((bytes_offset<64)?bytes_offset:32'd63))
   `$fatal(1,"header lookahead interface mismatch offset=%d",bytes_offset);
  #1;
  if(!rst && {$lhs} !== {$rhs})
   `$fatal(1,"old/new decoder cycle mismatch offset=%d",bytes_offset);
 end
"@
[IO.File]::WriteAllText("$out/stream_checked.v",'`timescale 1ns/1ps'+"`n"+$stream.Replace('endmodule',"$check`nendmodule"))
$bench=Get-Content "$root/diagnostics/image_scaling/tb_scale_stream.sv" -Raw
$bench=$bench.Replace('reg [31:0] size,offset;','reg [7:0] upstream=0; reg [31:0] size,offset;').Replace('offset,fe,8''d0,','offset,fe,upstream,').Replace('.upstream_error(8''d0)','.upstream_error(upstream)')
# Keep the original five-size pixel oracle, use file_start for subsequent
# images, and deliver file_end on the last byte (including partial sectors).
$bench=$bench.Replace('rst=1;checking=0;fv=0;fe=0;repeat(3)@(negedge clk);rst=0;',
 'checking=0;fv=0;fe=0;repeat(3)@(negedge clk);rst=0;')
$bench=$bench.Replace('fv=1;offset=i;byte_in=source(i);','fv=1;fe=(i==total-1);offset=i;byte_in=source(i);')
$bench=$bench.Replace('fv=0;fe=1;@(negedge clk);fe=0;','fv=0;fe=0;@(negedge clk);')
$abort=@'
 task cancel_image;
 begin
  @(negedge clk);checking=0;start=1;fv=0;fe=0;
  @(negedge clk);start=0;
  for(integer i=0;i<512;i=i+1)begin
   fv=1;offset=i;byte_in=source(i);@(negedge clk);
  end
  fv=0;
  wait(dut.decoder.pixels_started);
  @(negedge clk);upstream=1;@(negedge clk);upstream=0;
  repeat(20)@(negedge clk);
  if(error!=2 || done)$fatal(1,"cancel not propagated");
  $display("PASS stream cancel during replay, restart via file_start follows");
 end endtask
'@
$bench=$bench.Replace('initial begin' + "`r`n" + '  run_image', $abort + "`r`n initial begin`r`n  run_image")
# Source files may have LF endings on checkout.
if($bench -notmatch 'task cancel_image'){
 $bench=$bench.Replace("initial begin`n  run_image",$abort+"`n initial begin`n  run_image")
}
$bench=$bench.Replace('run_image(160,120);run_image(640,480);','run_image(160,120);cancel_image();run_image(640,480);')
[IO.File]::WriteAllText("$out/stream_bench.sv",$bench)
$generic=Get-Content "$root/diagnostics/stability/tb_bmp24_decoder.sv" -Raw
$generic=$generic.Replace('.bmp_done(done),.bmp_error(err));',
 '.bmp_done(done),.bmp_error(err),.pixel_ready(1''b1),.file_ready(),.image_width(),.image_height());')
# The production replay interface reports end after the final consumed byte.
# The legacy bench predates that contract; its direct same-cycle end fails
# identically on the baseline. Same-cycle upstream end is tested above through buffer.
$generic=$generic.Replace('ending=(i==send_size-1);','ending=0;')
$generic=$generic.Replace('repeat(5)@(negedge clk);',
 'ending=1;@(negedge clk);ending=0;repeat(5)@(negedge clk);')
$genericReference=[regex]::Match($generic,'(?s) bmp24_decoder #\(.*?\);').Value
$genericReference=$genericReference.Replace('bmp24_decoder #(','bmp24_decoder_reference #(').Replace(' dut(',' reference_decoder(')
foreach($port in $outputs){$genericReference=[regex]::Replace($genericReference,"\.$port\([^)]*\)",".$port()")}
$genericLhs=($signals | ForEach-Object {"dut.$_"}) -join ','
$genericCheck="`n$genericReference`n always @(posedge clk) begin #1; if(!rst && {$genericLhs} !== {$rhs}) `$fatal(1,`"generic decoder cycle mismatch`");end`n"
$generic=$generic.Replace('endmodule',"$genericCheck`nendmodule")
[IO.File]::WriteAllText("$out/generic_bench.sv",$generic)
$sim=$SimRoot;$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=@('bmp_sector_buffer','bmp_header_check','bmp24_decoder','image_scale_nearest') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
& "$sim/vlog.exe" -sv -work $lib "$TdRoot/sim_release/common/al_map_lut.v" @rtl "$out/reference.v" "$out/stream_checked.v" "$out/stream_bench.sv" "$out/generic_bench.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try {
 foreach($test in @('tb_scale_stream','tb_bmp24_decoder')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $test"}
  if($test -eq 'tb_scale_stream' -and $log -notmatch 'PASS stream cancel'){throw 'Missing cancel scenario'}
  if($test -eq 'tb_bmp24_decoder' -and ([regex]::Matches($log,'PASS decoder')).Count -ne 16){throw 'Missing generic decoder scenario'}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
