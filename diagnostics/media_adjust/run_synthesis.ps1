param([string]$BuildName='adjust_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName'}
$utf8=[Text.UTF8Encoding]::new($false)
foreach($module in @('media_adjust_control','media_adjust_cdc','brightness_contrast_adjust','pcm_master_volume','adjust_osd_overlay','mode_key_control')){
 $work=Join-Path $out $module
 New-Item -ItemType Directory -Path $work | Out-Null
 [xml]$xml=(Get-Content "$root/TD_project/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
 $entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
 $xml.Project.Source_Files.RemoveAll();$verilog=$xml.CreateElement('Verilog');$order=0
 foreach($source in @((Get-ChildItem "$root/user_source/hdl_source/adjust/*.v") + (Get-Item "$root/user_source/hdl_source/SD/mode_key_control.v","$root/user_source/hdl_source/SD/key_press_debounce.v","$root/user_source/hdl_source/osd/osd_pixel_position.v","$root/user_source/hdl_source/osd/osd_font_5x7.v"))){
  Copy-Item $source.FullName "$work/$($source.Name)"
  $file=$entry.CloneNode($true);$file.SetAttribute('Path',"$work/$($source.Name)".Replace('\','/'))
  $file.SelectSingleNode("FileInfo/Attr[@Name='CompileOrder']").SetAttribute('Val',[string]$order);$order++
  [void]$verilog.AppendChild($file)
 }
 [void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
 [IO.File]::WriteAllText("$work/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'),$utf8)
 $settings=@"
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {$module}
set run_type syn
set start_step read_design
set end_step opt_gate
"@
 [IO.File]::WriteAllText("$work/settings.cfg",$settings,$utf8)
 Push-Location $work
 try{
  & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> build.log
  $log=Get-Content build.log -Raw
  if($LASTEXITCODE -or $log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw "Synthesis failed: $module"}
  Write-Output "PASS standalone synthesis $module"
 }finally{Pop-Location}
}
