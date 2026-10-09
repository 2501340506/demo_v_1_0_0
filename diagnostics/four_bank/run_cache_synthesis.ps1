param([string]$BuildName='four_bank_s2_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName to preserve evidence'}
New-Item -ItemType Directory -Path $out | Out-Null
$module='media_frame_cache_control'
Copy-Item "$root/user_source/hdl_source/SD/$module.v" "$out/$module.v"
[xml]$xml=(Get-Content "$root/releases/v0.8.0/s1-local.1/project/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
$entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
$entry.SetAttribute('Path',"$out/$module.v".Replace('\','/'))
$xml.Project.Source_Files.RemoveAll()
$verilog=$xml.CreateElement('Verilog');[void]$verilog.AppendChild($entry)
[void]$xml.SelectSingleNode('/Project/Source_Files').AppendChild($verilog)
$utf8=[Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText("$out/demo.prj",$xml.OuterXml.Replace('UsedInP&amp;R','UsedInP&R'),$utf8)
# This is the real control clock, not TD's default unconstrained 50 MHz clock.
# No physical IO budgets or routed timing signoff are claimed for a standalone core.
[IO.File]::WriteAllText("$out/control.sdc",'create_clock -name sd_control -period 10.000 [get_ports clk]' + "`n",$utf8)
$settings=@"
set ADCList {}
set SDCList {control.sdc}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {$module}
set run_type syn
set start_step read_design
set end_step opt_gate
"@
[IO.File]::WriteAllText("$out/settings.cfg",$settings,$utf8)
Push-Location $out
try {
    & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> build.log
    if($LASTEXITCODE){throw "Standalone synthesis failed: $out/build.log"}
    $log=Get-Content build.log -Raw
    if($log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw 'Synthesis incomplete'}
    Write-Output "PASS cache controller standalone synthesis: $out"
} finally {Pop-Location}
