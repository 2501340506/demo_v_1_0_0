param([string]$RunName='mountain_m5_unit01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=@('SD/fat32_volume_scanner.v','SD/fat32_file_streamer.v','scene/bin_to_bram_loader.v','SD/seg7_panel.v','SD/seg_scan.v','SD/seg_decoder.v','adjust/adjust_osd_overlay.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
& "$sim/vlog.exe" -sv -work $lib @rtl "$PSScriptRoot/tb_m5_scan.sv" "$PSScriptRoot/tb_m5_loader.sv" "$PSScriptRoot/tb_m5_ui.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'M5 unit compile failed'}
foreach($bench in @('tb_m5_scan','tb_m5_loader','tb_m5_ui')){
 foreach($gap in $(if($bench -eq 'tb_m5_ui'){@(0)}else{@(0,2)})){
  & "$sim/vsim.exe" -c -quiet -lib $lib $bench @(if($bench -ne 'tb_m5_ui'){"-gGAP=$gap"}) -l "$out/${bench}_gap${gap}.log" -do 'run -all; quit -f' *> "$out/${bench}_gap${gap}_console.log"
  $log=Get-Content "$out/${bench}_gap${gap}.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning)' -or $log -notmatch 'PASS M5' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed $bench gap=$gap : $out"}
  Write-Output "PASS $bench GAP=$gap"
 }
}
