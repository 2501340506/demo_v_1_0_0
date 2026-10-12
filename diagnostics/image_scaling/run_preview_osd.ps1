param([string]$RunName='scale_s3_osd1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=Get-ChildItem "$root/user_source/hdl_source/audio_vis/*.v","$root/user_source/hdl_source/osd/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -sv -work $lib "+incdir+$root/user_source/hdl_source/SD" @rtl "$root/user_source/hdl_source/SD/color_bar.v" "$root/user_source/hdl_source/SD/video_timing_data.v" "$root/user_source/hdl_source/SD/thumbnail_layout.v" "$PSScriptRoot/tb_preview_osd.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'OSD compile failed'}
& "$sim/vsim.exe" -c -quiet -lib $lib tb_preview_osd -l "$out/osd.log" -do 'run -all; quit -f' *> "$out/console.log"
$log=Get-Content "$out/osd.log" -Raw
if($LASTEXITCODE -or $log -notmatch 'PASS preview OSD:' -or $log -match '\*\* (Fatal|Error|Warning):'){throw 'OSD test failed'}
Write-Output 'PASS preview OSD: and all OSD alignment'
