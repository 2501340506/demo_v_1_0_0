param(
    [string]$BuildName = 'audio_s0_local1',
    [string]$TdRoot = 'D:/TD/anlogic/TD6.2.1',
    [switch]$HighFanoutOptimization,
    [switch]$PlaceHoldFix,
    [ValidateSet('medium','high','ultra')][string]$TimingOptimization = 'medium',
    [ValidateSet('auto','high','ultra')][string]$PostPlaceOptimization = 'auto'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$projectDir = Join-Path $repoRoot 'TD_project'
$utf8 = [Text.UTF8Encoding]::new($false)
# TD writes the literal attribute value UsedInP&R, unlike standard XML.
$projectText = Get-Content -LiteralPath (Join-Path $projectDir 'demo.al') -Encoding UTF8 -Raw
[xml]$project = $projectText.Replace('UsedInP&R', 'UsedInP&amp;R')

# Use the GUI project as the source of truth for each command-line run.
foreach ($entry in $project.SelectNodes('/Project/Source_Files/*/File')) {
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $projectDir $entry.GetAttribute('Path')))
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing source: $sourcePath" }
    $entry.SetAttribute('Path', $sourcePath.Replace('\', '/'))
}
foreach ($node in @($project.SelectNodes('/Project/Runs | /Project/Project_Settings'))) {
    [void]$node.ParentNode.RemoveChild($node)
}
$project.Project.SetAttribute('RunTime', (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'))
$adc = (Join-Path $repoRoot 'user_source/constraints_source/pin.adc').Replace('\', '/')
$sdc = (Join-Path $repoRoot 'user_source/constraints_source/timing.sdc').Replace('\', '/')
$commonSettings = @"
set ADCList {{${adc}}}
set SDCList {{${sdc}}}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name {demo}
set top_model_name {top}
"@

foreach ($run in @('syn_1', 'phy_1')) {
    $runDir = Join-Path $projectDir "demo_Runs/$run"
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $runDir 'demo.prj'), $project.OuterXml.Replace('UsedInP&amp;R', 'UsedInP&R'), $utf8)
    $runSettings = if ($run -eq 'syn_1') {
        "set run_type syn`nset start_step read_design`nset end_step opt_gate`n"
    } else {
        "set run_type phy`nset parent ../syn_1`nset start_step opt_place`nset end_step bitgen`nset arr_filter false`nset drHoldFix on`n"
    }
    if ($run -eq 'phy_1') {
        $physicalOptions = @()
        if ($HighFanoutOptimization) { $physicalOptions += 'place hfn_opt_effort high' }
        if ($PlaceHoldFix) { $physicalOptions += 'place fix_hold high' }
        if ($TimingOptimization -ne 'medium') { $physicalOptions += "place opt_timing $TimingOptimization" }
        if ($PostPlaceOptimization -ne 'auto') { $physicalOptions += "place post_place_opt $PostPlaceOptimization" }
        if ($physicalOptions.Count -gt 0) {
            $runSettings += "set phyWildParams {$($physicalOptions -join ' ')}`n"
        }
    }
    [IO.File]::WriteAllText((Join-Path $runDir 'settings.cfg'), "$commonSettings`n$runSettings", $utf8)
}

foreach ($run in @('syn_1', 'phy_1')) {
    $runDir = Join-Path $projectDir "demo_Runs/$run"
    $logPath = Join-Path $runDir "build_$BuildName.log"
    Push-Location $runDir
    try {
        & "$TdRoot/bin/td_commands_prompt.exe" "$TdRoot/doc/scripts/DefaultFlow.tcl" *> $logPath
        if ($LASTEXITCODE -ne 0) { throw "TD failed: $logPath" }
        $log = Get-Content -LiteralPath $logPath -Raw
        if ($log -match '(?im)\bERROR:') { throw "TD reported errors: $logPath" }
        if ($run -eq 'phy_1' -and $log -notmatch 'Generate bitstream completely') {
            throw "No bitgen completion marker: $logPath"
        }
        Write-Output "PASS TD $run : $logPath"
    } finally { Pop-Location }
}
