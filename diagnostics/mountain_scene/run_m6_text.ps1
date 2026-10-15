param([string]$Card='m6_demo',[string]$RunName='mountain_m6_text01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I "$PSScriptRoot/text_vectors.py" $out "$root/tools/scenes/$Card/generated"
if($LASTEXITCODE){throw 'Text vectors failed'}
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
$files=@('scene/scene_bram32k.v','scene/scene_text_overlay.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
& "$sim/vlog.exe" -sv -work $lib @files "$PSScriptRoot/tb_m6_text.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'M5 text compile failed'}
$sizes=Get-Content "$out/sizes.json" -Raw | ConvertFrom-Json
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_m6_text glbl "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" -l "$out/text.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/text.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M6 text:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Text test failed: $out"}
 Write-Output "PASS M6 text: $out"
}finally{Pop-Location}
