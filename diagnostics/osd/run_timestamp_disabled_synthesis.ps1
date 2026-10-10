param([string]$BuildName='v010_s3_disabled1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName'}
New-Item -ItemType Directory -Path $out | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$wrapper=@'
module timestamp_disabled(input clk,rst,vs,de,input [9:0] pixel_x,
 input [23:0] rgb_in,output [23:0] rgb_out,output active);
 timestamp_osd #(.ENABLE(0)) dut(.clk(clk),.rst(rst),.vs(vs),.de(de),
  .pixel_x(pixel_x),.rgb_in(rgb_in),.rgb_out(rgb_out),.active(active));
endmodule
'@
[IO.File]::WriteAllText("$out/timestamp_disabled.v",$wrapper,$utf8)
[xml]$xml=([IO.File]::ReadAllText("$root/TD_project/demo.al")).Replace('UsedInP&R','UsedInP&amp;R')
foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
$template=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
$xml.Project.Source_Files.RemoveAll()
$verilog=$xml.CreateElement('Verilog')
$files=@('timestamp_osd','osd_pixel_position','osd_font_5x7')
$paths=@()
foreach($file in $files){Copy-Item "$root/user_source/hdl_source/osd/$file.v" "$out/$file.v";$paths+="$out/$file.v"}
$paths+="$out/timestamp_disabled.v"
foreach($path in $paths){$entry=$template.CloneNode($true);$entry.SetAttribute('Path',$path.Replace('\','/'));[void]$verilog.AppendChild($entry)}
[void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
[IO.File]::WriteAllText("$out/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'),$utf8)
$settings=@'
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {timestamp_disabled}
set run_type syn
set start_step read_design
set end_step opt_gate
'@
[IO.File]::WriteAllText("$out/settings.cfg",$settings,$utf8)
Push-Location $out
try {
 & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> build.log
 if($LASTEXITCODE){throw 'Disabled synthesis failed'}
 $log=Get-Content build.log -Raw
 if($log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw 'Disabled synthesis incomplete'}
 $area=Get-Content demo_gate.area -Raw
 foreach($resource in @('lut','reg','bram','dsp','pll')){
  if($area -notmatch "(?m)^#$resource\s+0\s+out of"){throw "Disabled timestamp retained $resource"}
 }
 Write-Output "PASS disabled timestamp: zero LUT/register/BRAM/DSP/PLL; $out/demo_gate.area"
}finally{Pop-Location}
