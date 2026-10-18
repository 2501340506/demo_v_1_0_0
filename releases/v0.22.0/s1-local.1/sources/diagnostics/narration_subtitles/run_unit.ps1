param([string]$RunName='narration_unit01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I -X utf8 "$root/tools/publicity/make_narration_subtitles.py" --out $out
if($LASTEXITCODE){throw 'Vectors failed'}
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/scene/scene_bram32k.v" "$root/user_source/hdl_source/scene/scene_text_overlay.v" "$root/user_source/hdl_source/osd/osd_pixel_position.v" "$PSScriptRoot/tb_narration.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_narration glbl -l "$out/test.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/test.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS narration:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw 'Narration test failed'}
 Write-Output ($log -split "`n" | Where-Object {$_ -match 'PASS narration:'})
}finally{Pop-Location}
