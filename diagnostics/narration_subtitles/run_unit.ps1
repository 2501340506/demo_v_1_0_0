param([string]$RunName='narration_unit01',[string]$Base='',[string]$Pcm='',[string]$Python='')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
# Content folder (scripts/page1-4.txt) and VOI1-4.PCM folder; default is the v0.22 pack.
$gen=@('--out',$out);if($Base){$gen+=@('--base',$Base)};if($Pcm){$gen+=@('--pcm',$Pcm,'--preview',$Pcm)}
if(!$Python){$Python="$env:USERPROFILE/scoop/apps/python/current/python.exe"}  # needs Pillow
& $Python -I -X utf8 "$root/tools/publicity/make_narration_subtitles.py" @gen
if($LASTEXITCODE){throw 'Vectors failed'}
$sim='d:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'd:/TD/anlogic/TD6.2.1/sim_release/eg4/*.v','d:/TD/anlogic/TD6.2.1/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
& "$sim/vlog.exe" -sv -work $lib "+incdir+$out" "$root/user_source/hdl_source/scene/scene_bram32k.v" "$root/user_source/hdl_source/scene/scene_text_overlay.v" "$root/user_source/hdl_source/osd/osd_pixel_position.v" "$PSScriptRoot/tb_narration.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_narration glbl -l "$out/test.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/test.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS narration:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw 'Narration test failed'}
 Write-Output ($log -split "`n" | Where-Object {$_ -match 'PASS narration:'})
}finally{Pop-Location}
