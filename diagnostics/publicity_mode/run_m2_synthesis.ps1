param([string]$BuildName='publicity_m2_syn01',[string]$PreparedRun='publicity_m2_attempt03')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Use a fresh BuildName'}
$utf8=[Text.UTF8Encoding]::new($false)
$all=@('fat32_bmp_reader','sd_sector_adapter','sd_sector_service','fat32_volume_scanner','fat32_file_streamer','bmp_header_check','bmp24_decoder','bmp_scale_stream','bmp_sector_buffer','image_scale_nearest')
foreach($module in @('fat32_volume_scanner','fat32_bmp_reader')){
 $work="$out/$module";New-Item -ItemType Directory -Path $work -Force | Out-Null
 $modules=if($module -eq 'fat32_volume_scanner'){@('fat32_volume_scanner')}else{$all}
 $files=@()
 foreach($source in $modules){Copy-Item "$root/user_source/hdl_source/SD/$source.v" "$work/$source.v";$files+="$work/$source.v"}
 $wrapper="${module}_enabled.v"
 Copy-Item "$root/diagnostics/output/$PreparedRun/$wrapper" "$work/$wrapper";$files+="$work/$wrapper"
 [xml]$xml=(Get-Content -Raw "$root/releases/v0.5.3/v0.5.3-baseline/demo.al").Replace('UsedInP&R','UsedInP&amp;R')
 foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
 $entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
 $xml.Project.Source_Files.RemoveAll();$verilog=$xml.CreateElement('Verilog')
 $order=0
 foreach($file in $files){$item=$entry.CloneNode($true);$item.SetAttribute('Path',$file.Replace('\','/'));$order++;$item.SelectSingleNode('FileInfo/Attr[@Name="CompileOrder"]').SetAttribute('Val',[string]$order);[void]$verilog.AppendChild($item)}
 [void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
 [IO.File]::WriteAllText("$work/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'),$utf8)
 $settings=@"
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {${module}_enabled}
set run_type syn
set start_step read_design
set end_step opt_gate
"@
 [IO.File]::WriteAllText("$work/settings.cfg",$settings,$utf8)
 Push-Location $work
 try{
 & E:/TD/bin/td_commands_prompt.exe E:/TD/doc/scripts/DefaultFlow.tcl *> build.log
 if($LASTEXITCODE -or (Get-Content -Raw build.log) -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw "TD synthesis failed: $work"}
 foreach($source in $modules){
  $a=[IO.File]::ReadAllBytes("$root/user_source/hdl_source/SD/$source.v");$b=[IO.File]::ReadAllBytes("$work/$source.v")
  if($a.Length -ne $b.Length -or [Convert]::ToBase64String($a) -cne [Convert]::ToBase64String($b)){throw "Source snapshot mismatch $source"}
 }
 Write-Output "PASS enabled standalone synthesis $module; $($modules.Count) RTL files byte-identical"
 }finally{Pop-Location}
}
