param(
    [string]$BuildName = 'audio_s0_local1',
    [string]$TdRoot = 'D:/TD/anlogic/TD6.2.1',
    [switch]$HighFanoutOptimization,
    [switch]$PlaceHoldFix,
    [switch]$PostRouteOptimization,
    [switch]$DisablePostRouteOptimization,
    [switch]$HighPlaceEffort,
    [switch]$HighRouteEffort,
    [switch]$HighAreaOptimization,
    [switch]$HighPackingOptimization,
    [ValidateRange(1,11)][int]$PlacementStrategy=1,
    [ValidateRange(0,2147483647)][int]$PlacementSeed=0,
    [ValidateSet('medium','high','ultra')][string]$TimingOptimization = 'medium',
    [ValidateSet('auto','high','ultra')][string]$PostPlaceOptimization = 'auto',
    [ValidateSet('auto','lower_pin_density','adaptive_pin_density','more_lut_pair')][string]$PackMode = 'auto'
)
$ErrorActionPreference = 'Stop'
if ($PostRouteOptimization -and $DisablePostRouteOptimization) { throw 'Choose either high or disabled post-route optimization' }
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
        if ($PackMode -ne 'auto') { $physicalOptions += "place pack_mode $PackMode" }
        if ($PlacementSeed -ne 0) { $physicalOptions += "place seed $PlacementSeed" }
        if ($HighFanoutOptimization) { $physicalOptions += 'place hfn_opt_effort high' }
        if ($PlaceHoldFix) { $physicalOptions += 'place fix_hold high' }
        if ($PostRouteOptimization) { $physicalOptions += 'route post_route_opt high route postrt_opt_extra_round 4' }
        if ($DisablePostRouteOptimization) { $physicalOptions += 'route post_route_opt off' }
        if ($HighPlaceEffort) { $physicalOptions += 'place effort high' }
        # TD route effort accepts normal/routability (not placement's high).
        if ($HighRouteEffort) { $physicalOptions += 'route effort routability' }
        if ($PlacementStrategy -ne 1) { $physicalOptions += "place pr_strategy $PlacementStrategy" }
        if ($TimingOptimization -ne 'medium') { $physicalOptions += "place opt_timing $TimingOptimization" }
        if ($PostPlaceOptimization -ne 'auto') { $physicalOptions += "place post_place_opt $PostPlaceOptimization" }
        if ($physicalOptions.Count -gt 0) {
            $runSettings += "set phyWildParams {$($physicalOptions -join ' ')}`n"
        }
    }
    if ($run -eq 'syn_1' -and $HighAreaOptimization) {
        $runSettings += "set synWildParams {gate opt_area high gate pack_effort high}`n"
    } elseif ($run -eq 'syn_1' -and $HighPackingOptimization) {
        $runSettings += "set synWildParams {gate pack_effort high}`n"
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
