param([Parameter(Mandatory=$true)][string]$RunName,[Parameter(Mandatory=$true)][string]$Cards,[string]$Overlay='')
# v0.25 S5: card switch. tb_m6_text loads one scene's FONT/TEXT, checks it, then loads the next
# scene's FONT/TEXT while text_valid stays high (as on the board, where the load is shorter than
# a frame) and only resource_generation toggles; every pixel of all four stages must then come
# from the new card. -Overlay picks another scene_text_overlay.v (e.g. the old one, to show the bug).
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
if(!$Overlay){$Overlay="$root/user_source/hdl_source/scene/scene_text_overlay.v"}
$sim='D:/modelsim/win64';$td='D:/TD/anlogic/TD6.2.1'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem "$td/sim_release/eg4/*.v","$td/sim_release/common/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
$rtl=@('scene/scene_bram32k.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
& "$sim/vlog.exe" -sv -work $lib $Overlay @rtl "$root/diagnostics/mountain_scene/tb_m6_text.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
$pairs=@(@('landslide_village','debris_village'),@('debris_village','flood_village'),@('flood_village','quake_village'),@('quake_village','landslide_village'))
$failed=0
foreach($p in $pairs){
 $case="$out/$($p[0])_to_$($p[1])"; New-Item -ItemType Directory $case | Out-Null
 & $python -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $case "$Cards/$($p[0])"
 $s1=Get-Content "$case/sizes.json" -Raw | ConvertFrom-Json
 $two="$case/second"; New-Item -ItemType Directory $two | Out-Null
 & $python -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $two "$Cards/$($p[1])"
 Copy-Item "$two/font.hex" "$case/font2.hex"; Copy-Item "$two/text.hex" "$case/text2.hex"
 $s2=Get-Content "$two/sizes.json" -Raw | ConvertFrom-Json
 Push-Location $case
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_m6_text glbl "+F_BYTES=$($s1.font)" "+T_BYTES=$($s1.text)" "+SWITCH=1" "+F2_BYTES=$($s2.font)" "+T2_BYTES=$($s2.text)" -l "$case/text.log" -do 'run -all; quit -f' *> "$case/console.log"
  $log=Get-Content -Raw "$case/text.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS card switch' -or $log -notmatch 'PASS M6 text:'){
   $failed++;Write-Output "FAIL $($p[0]) -> $($p[1]): $(([regex]'\*\* Fatal[^\r\n]*').Match($log).Value)"
  }else{Write-Output "PASS switch $($p[0]) -> $($p[1])"}
 }finally{Pop-Location}
}
if($failed){exit 1}
