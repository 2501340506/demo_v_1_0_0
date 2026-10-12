param([string]$RunName='ring_s1_music1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
python "$PSScriptRoot/music_preview.py" prepare $out
if($LASTEXITCODE){throw 'PCM preparation failed'}
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=Get-ChildItem "$root/user_source/hdl_source/audio_vis/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -sv "+incdir+$root/user_source/hdl_source/SD" -work $lib @rtl "$root/user_source/hdl_source/SD/color_bar.v" "$root/user_source/hdl_source/SD/video_timing_data.v" "$root/user_source/hdl_source/osd/osd_pixel_position.v" "$PSScriptRoot/tb_ring_music.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'music compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_ring_music -l "$out/music.log" -do 'run -all; quit -f' *> "$out/music.console.log"
 $log=Get-Content "$out/music.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS music:' -or $log -match '\*\* (Fatal|Error):'){throw 'music simulation failed'}
}finally{Pop-Location}
python "$PSScriptRoot/music_preview.py" render $out
if($LASTEXITCODE){throw 'preview failed'}
