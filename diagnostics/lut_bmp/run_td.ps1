param([string]$BuildName='v053_reproduce', [switch]$Baseline)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName to preserve previous results'}
New-Item -ItemType Directory -Path "$out/TD_project","$out/diagnostics" -Force | Out-Null
Copy-Item "$root/user_source" "$out/user_source" -Recurse
Copy-Item "$root/releases/v0.5.3/v0.5.3-baseline/demo.al" "$out/TD_project/demo.al"
Copy-Item "$root/diagnostics/run_td_build.ps1" "$out/diagnostics/run_td_build.ps1"
if($Baseline){Copy-Item "$root/releases/v0.5.3/v0.5.3-baseline/bmp_read.v" "$out/user_source/hdl_source/SD/bmp_read.v"}
& powershell -NoProfile -ExecutionPolicy Bypass -File "$out/diagnostics/run_td_build.ps1" -BuildName $BuildName -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
if($LASTEXITCODE){throw 'TD build failed'}
