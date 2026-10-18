param([Parameter(Mandatory=$true)][string]$Assets,
 [string]$RunName='s2_card_text01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
$rtl=@('scene/scene_bram32k.v','scene/scene_text_overlay.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
& "$sim/vlog.exe" -sv -work $lib @rtl "$root/diagnostics/mountain_scene/tb_m6_text.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
foreach($folder in @('landslide_village','debris_village','flood_village','quake_village')){
 $case="$out/$folder"
 New-Item -ItemType Directory $case | Out-Null
 & py -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $case "$Assets/$folder"
 if($LASTEXITCODE){throw 'Vectors failed'}
 $sizes=Get-Content "$case/sizes.json" -Raw | ConvertFrom-Json
 Push-Location $case
 try {
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_m6_text glbl "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" -l "$case/text.log" -do 'run -all; quit -f' *> "$case/console.log"
  $log=Get-Content "$case/text.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M6 text:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Text test failed: $case"}
  Write-Output "PASS card text $folder"
 }finally{Pop-Location}
}
