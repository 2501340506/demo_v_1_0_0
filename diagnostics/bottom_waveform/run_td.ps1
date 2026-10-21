param([string]$BuildName='bottom_wave_td01',[int]$Seed=43,[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a fresh build name'}
New-Item -ItemType Directory "$out/TD_project","$out/diagnostics" -Force | Out-Null
Copy-Item "$root/user_source" "$out/user_source" -Recurse
# Preserve the user's open GUI project; use the committed project definition.
$project=git -C $root show HEAD:TD_project/demo.al
[IO.File]::WriteAllText("$out/TD_project/demo.al",($project -join "`n"),[Text.UTF8Encoding]::new($false))
Copy-Item "$root/diagnostics/run_td_build.ps1" "$out/diagnostics/run_td_build.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$out/diagnostics/run_td_build.ps1" -BuildName $BuildName -TdRoot $TdRoot -HighAreaOptimization -PackMode more_lut_pair -PlacementSeed $Seed -HighFanoutOptimization -PlaceHoldFix -PostRouteOptimization -HighPlaceEffort -HighRouteEffort -TimingOptimization ultra -PostPlaceOptimization high
if($LASTEXITCODE){throw 'TD build failed'}
$report=Get-Content "$out/TD_project/demo_Runs/phy_1/final_timing.rpt" -Raw
foreach($metric in @('SWNS','HWNS','STNS','HTNS')){
 $m=[regex]::Match($report,$metric+':\s*([-\d.]+)ns')
 if(!$m.Success){throw "Missing $metric"}
 $value=[double]$m.Groups[1].Value
 if(($metric -in @('SWNS','HWNS') -and $value -le 0) -or ($metric -in @('STNS','HTNS') -and $value -ne 0)){throw "Timing failed: $metric=$value"}
 Write-Output "$metric=$value"
}
