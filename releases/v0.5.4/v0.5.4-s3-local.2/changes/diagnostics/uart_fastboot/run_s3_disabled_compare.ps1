param([string]$RunName='v054_s3_disabled_compare')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$old=(& git -C $root show 'v0.5.4-s2-board.2:user_source/hdl_source/SD/bmp_read.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read accepted S2 parser'}
$old=$old.Replace('module bmp_read #(','module bmp_read_s2 #(')
[IO.File]::WriteAllText("$out/bmp_read_s2.v",$old,[Text.UTF8Encoding]::new($false))
$lib=(Join-Path $out 'work').Replace('\','/')
if(!(Test-Path "$lib/_info")){& "$sim/vlib.exe" $lib}
& "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" "$out/bmp_read_s2.v" "$root/user_source/hdl_source/SD/bmp_read.v" "$root/diagnostics/stability/sim_bmp_sectors.sv" "$root/diagnostics/stability/tb_bmp_baseline.sv" "$PSScriptRoot/tb_s3_disabled_compare.sv"
if($LASTEXITCODE){throw 'Compile failed'}
& "$sim/vsim.exe" -c -lib $lib tb_s3_disabled_compare -l "$out/test.log" -do 'run -all; quit -f'
$log=Get-Content "$out/test.log" -Raw
if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS S2/S3 cycle comparison' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw 'S2/S3 comparison failed'}
