param([string]$BuildName='fat32_s2_syn1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Use a new BuildName to retain previous results'}
$utf8=[Text.UTF8Encoding]::new($false)
foreach($module in @('fat32_volume_scanner','fat32_file_streamer')){
    $work=Join-Path $out $module
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    Copy-Item "$root/user_source/hdl_source/SD/$module.v" "$work/$module.v"
    # Fixed published project provides device settings; do not read or modify
    # the user's uncommitted GUI project or best_result.
    [xml]$xml=(Get-Content "$root/releases/v0.5.3/v0.5.3-baseline/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
    foreach($node in @($xml.SelectNodes('/Project/Runs | /Project/Project_Settings'))){[void]$node.ParentNode.RemoveChild($node)}
    $entry=$xml.SelectSingleNode('/Project/Source_Files/Verilog/File').CloneNode($true)
    $entry.SetAttribute('Path',"$work/$module.v".Replace('\','/'))
    $xml.Project.Source_Files.RemoveAll()
    $verilog=$xml.CreateElement('Verilog');[void]$verilog.AppendChild($entry)
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
    try {
        & D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe D:/TD/anlogic/TD6.2.1/doc/scripts/DefaultFlow.tcl *> build.log
        if($LASTEXITCODE){throw "TD synthesis failed: $module"}
        $log=Get-Content build.log -Raw
        if($log -match '(?im)\bERROR:' -or !(Test-Path demo_gate.area)){throw "TD synthesis incomplete: $module"}
        Write-Output "PASS standalone synthesis $module : $work"
    } finally {Pop-Location}
}
