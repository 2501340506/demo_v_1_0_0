param([string]$BuildName='decoder_s1_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Use a new build name'}
New-Item -ItemType Directory $out | Out-Null
Copy-Item "$root/user_source/hdl_source/SD/bmp_header_check.v","$root/user_source/hdl_source/SD/bmp24_decoder.v" $out
$source="$out/bmp24_decoder.v".Replace('\','/')
[xml]$xml=(Get-Content "$root/releases/v0.5.3/v0.5.3-baseline/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
$entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
$entry.SetAttribute('Path',$source)
$xml.Project.Source_Files.RemoveAll()
$verilog=$xml.CreateElement('Verilog');[void]$verilog.AppendChild($entry)
$headerEntry=$entry.CloneNode($true)
$headerEntry.SetAttribute('Path',"$out/bmp_header_check.v".Replace('\','/'))
[void]$verilog.AppendChild($headerEntry)
[void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
[IO.File]::WriteAllText("$out/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'))
$settings=@'
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {bmp24_decoder}
set run_type syn
set start_step read_design
set end_step opt_gate
'@
[IO.File]::WriteAllText("$out/settings.cfg",$settings)
Push-Location $out
try {
 & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> build.log
 if($LASTEXITCODE){throw 'TD synthesis failed'}
 if((Get-Content build.log -Raw) -match '(?im)\bERROR:'){throw 'TD reported error'}
 Write-Output "PASS standalone TD synthesis $out"
} finally {Pop-Location}

