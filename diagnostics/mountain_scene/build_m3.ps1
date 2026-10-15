param([string]$BuildName='mountain_scene_m3_attempt02',[string]$TdRoot='E:/TD',
 [int]$PlacementStrategy=5,[ValidateSet('medium','high','ultra')][string]$TimingOptimization='high')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a fresh BuildName'}
New-Item -ItemType Directory "$out/TD_project","$out/diagnostics" | Out-Null
Copy-Item -LiteralPath "$root/user_source" -Destination $out -Recurse
Copy-Item -LiteralPath "$root/TD_project/demo.al" -Destination "$out/TD_project/demo.al"
Copy-Item -LiteralPath "$root/diagnostics/run_td_build.ps1" -Destination "$out/diagnostics/run_td_build.ps1"
& "$out/diagnostics/run_td_build.ps1" -BuildName $BuildName -TdRoot $TdRoot -HighFanoutOptimization -PlacementStrategy $PlacementStrategy -TimingOptimization $TimingOptimization
