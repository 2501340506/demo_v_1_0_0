param([Parameter(Mandatory=$true)][string]$BuildName,[Parameter(Mandatory=$true)][string]$Top,[Parameter(Mandatory=$true)][string[]]$Files,
 [string]$TdRoot='d:/TD/anlogic/TD6.2.1')
# Standalone TD synthesis (read_design..opt_gate) of one module, using the
# committed project device settings, as in diagnostics/fat32/run_core_synthesis.ps1.
$ErrorActionPreference='Stop'
# powershell -File passes a comma list as one string.
$Files=@($Files | ForEach-Object {$_ -split ","} | Where-Object {$_})
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Use a new BuildName to retain previous results'}
New-Item -ItemType Directory -Path $out | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
[xml]$xml=((git -C $root show HEAD:TD_project/demo.al) -join "`n").Replace('UsedInP&R','UsedInP&amp;R')
foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
$template=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File')
$xml.Project.Source_Files.RemoveAll()
$verilog=$xml.CreateElement('Verilog')
foreach($file in $Files){
 $copy=Join-Path $out (Split-Path $file -Leaf)
 Copy-Item $file $copy
 $entry=$template.CloneNode($true);$entry.SetAttribute('Path',$copy.Replace('\','/'))
 [void]$verilog.AppendChild($entry)
}
[void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
[IO.File]::WriteAllText("$out/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'),$utf8)
$settings=@"
set ADCList {}
set SDCList {}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {$Top}
set run_type syn
set start_step read_design
set end_step opt_gate
"@
[IO.File]::WriteAllText("$out/settings.cfg",$settings,$utf8)
Push-Location $out
try{
 & "$TdRoot/bin/td_commands_prompt.exe" "$TdRoot/doc/scripts/DefaultFlow.tcl" *> build.log
 if($LASTEXITCODE){throw "TD synthesis failed: $Top"}
 $log=Get-Content build.log -Raw
 if($log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw "TD synthesis incomplete: $Top"}
 Write-Output "PASS standalone synthesis $Top : $out"
}finally{Pop-Location}
