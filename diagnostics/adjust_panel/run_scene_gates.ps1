param([string]$RunName='adjust_scene_gates1',[string]$Card='')
# v0.27: the panel's OSD and SCROLL switches in the scene app. Renders one frame of a real
# card through the real scene_text_overlay three times (both on, OSD off, SCROLL off) over a
# flat picture and compares the panel, legend and subtitle regions (scene_gates.py), then
# writes PNGs of the three frames.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
if(!$Card){$Card="$root/releases/v0.25.0/s5-card.2/card/landslide_village"}
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='d:/modelsim/win64'
$td='d:/TD/anlogic/TD6.2.1'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
$vendor=Get-ChildItem "$td/sim_release/eg4/*.v","$td/sim_release/common/*.v" | ForEach-Object {$_.FullName}
$rtl=@('scene/scene_text_overlay.v','scene/scene_bram32k.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
& "$sim/vlog.exe" -sv -work $lib @rtl "$root/diagnostics/lut_opt25/tb_osd_render.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
& $python -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $out $Card
if($LASTEXITCODE){throw 'Vectors failed'}
$sizes=Get-Content "$out/sizes.json" -Raw | ConvertFrom-Json
[IO.File]::WriteAllText("$out/bg.hex",(("4a6e8c`n")*307200),[Text.Encoding]::ASCII)
Push-Location $out
try{
 foreach($case in @(@('on',1,1),@('hud',0,1),@('sub',1,0))){
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_osd_render glbl "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" "+STAGE=3" "+T=239" "+SCROLL=624" "+FRAMES=32" "+HUD=$($case[1])" "+SUB=$($case[2])" -l "$out/$($case[0]).log" -do 'run -all; quit -f' *> "$out/$($case[0]).console.log"
  $log=Get-Content -Raw "$out/$($case[0]).log"
  if($LASTEXITCODE -or $log -notmatch 'RENDERED' -or $log -match '\*\* (Fatal|Error):'){throw "Render failed: $out/$($case[0]).log"}
  Move-Item frame.hex "$($case[0]).hex"
  & $python -I "$root/diagnostics/lut_opt25/osd_preview/topng.py" "$($case[0]).hex" "$($case[0]).png"
 }
 & $python -I -X utf8 "$PSScriptRoot/scene_gates.py" $out
 if($LASTEXITCODE){throw 'Scene gate check failed'}
}finally{Pop-Location}
