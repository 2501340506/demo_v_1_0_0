param([string]$RunName='v054_s3_scan_resume')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$lib=(Join-Path $out 'work').Replace('\','/')
if (-not (Test-Path "$lib/_info")) { & "$sim/vlib.exe" $lib }
& "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" "$root/user_source/hdl_source/SD/bmp_read.v" "$PSScriptRoot/tb_scan_resume.sv"
if($LASTEXITCODE){throw 'Scan resume compile failed'}
& "$sim/vsim.exe" -c -lib $lib tb_scan_resume -l "$out/test.log" -do 'run -all; quit -f'
$log=Get-Content "$out/test.log" -Raw
if($LASTEXITCODE -or $log -match '\*\* (Error|Fatal):' -or $log -notmatch 'PASS new scan' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw 'Scan resume simulation failed'}
Write-Output 'PASS scan pause/load/resume reference comparison'
