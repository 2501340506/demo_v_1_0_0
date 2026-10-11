param([string]$BuildName='pcm_s2_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Use a new BuildName'}
$utf8=[Text.UTF8Encoding]::new($false)
$modules=@('pcm_stream_player','fat32_pcm_stream','audio_source_mux','audio_scan_synthesis')
foreach($module in $modules){
 $work=Join-Path $out $module
 New-Item -ItemType Directory -Path $work | Out-Null
 $sources=switch($module){
  'fat32_pcm_stream' {@('user_source/hdl_source/audio/fat32_pcm_stream.v','user_source/hdl_source/SD/fat32_file_streamer.v')}
  'audio_scan_synthesis' {@('diagnostics/pcm_audio/audio_scan_synthesis.v','user_source/hdl_source/SD/fat32_volume_scanner.v')}
  default {@("user_source/hdl_source/audio/$module.v")}
 }
 [xml]$xml=(Get-Content "$root/TD_project/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
 $entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
 $xml.Project.Source_Files.RemoveAll()
 $verilog=$xml.CreateElement('Verilog')
 $order=0
 foreach($source in $sources){
  $name=Split-Path $source -Leaf
  Copy-Item "$root/$source" "$work/$name"
  $file=$entry.CloneNode($true);$file.SetAttribute('Path',"$work/$name".Replace('\','/'))
  $file.SelectSingleNode("FileInfo/Attr[@Name='CompileOrder']").SetAttribute('Val',[string]$order)
  $order++
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
  if($LASTEXITCODE){throw "TD synthesis failed: $module"}
  $log=Get-Content build.log -Raw
  if($log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw "Synthesis incomplete: $module"}
  Write-Output "PASS standalone synthesis $module"
 }finally{Pop-Location}
}
