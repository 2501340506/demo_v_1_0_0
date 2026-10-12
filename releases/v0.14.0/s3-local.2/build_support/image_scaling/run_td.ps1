param([string]$BuildName='scale_s2_attempt1',[switch]$PlaceHoldFix,
 [ValidateSet('high','ultra')][string]$TimingOptimization='high')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName'}
New-Item -ItemType Directory -Path "$out/TD_project","$out/diagnostics" -Force | Out-Null
Copy-Item "$root/user_source" "$out/user_source" -Recurse
Copy-Item "$root/TD_project/demo.al" "$out/TD_project/demo.al"
Copy-Item "$root/diagnostics/run_td_build.ps1" "$out/diagnostics/run_td_build.ps1"
$holdArgs=@();if($PlaceHoldFix){$holdArgs=@('-PlaceHoldFix')}
& powershell -NoProfile -ExecutionPolicy Bypass -File "$out/diagnostics/run_td_build.ps1" -BuildName $BuildName -HighFanoutOptimization -TimingOptimization $TimingOptimization -PostPlaceOptimization high @holdArgs
if($LASTEXITCODE){throw 'TD build failed'}
$report=Get-Content "$out/TD_project/demo_Runs/phy_1/final_timing.rpt" -Raw
$setup=[regex]::Match($report,'SWNS:\s*([-\d.]+)ns');$hold=[regex]::Match($report,'HWNS:\s*([-\d.]+)ns')
if(!$setup.Success -or !$hold.Success){throw 'Missing timing summary'}
if([double]$setup.Groups[1].Value -lt 0 -or [double]$hold.Groups[1].Value -lt 0){throw 'Timing failed; not a candidate'}
Write-Output "PASS routed timing: Setup $($setup.Groups[1].Value) ns, Hold $($hold.Groups[1].Value) ns"
