param([string]$RunName='lut25_overlay1',[string]$Cards='',[string]$Legacy='')
# v0.25 S5: the scene HUD (alert block, progress bar) and the legend.
#  1. tb_m6_text on 14-segment legend cards, 10-segment cards and frozen older cards: every pixel and
#     video bundle against an independent model, plus invalid-file cases.
#  2. mutants of the overlay (layout, colours, blink, scroll, parsing) that the bench must catch.
# (The lockstep against the frozen S3 overlay was retired: the text layout changed on purpose.)
# -Cards: folder with <scene>_village/{FONT.BIN,TEXT.BIN} of 14 segments; -Legacy: same, 10 segments.
$ErrorActionPreference='Stop'
if(!$Cards){throw '-Cards is required'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='D:/modelsim/win64'
$td='D:/TD/anlogic/TD6.2.1'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
$vendor=Get-ChildItem "$td/sim_release/eg4/*.v","$td/sim_release/common/*.v" | ForEach-Object {$_.FullName}
$overlay="$root/user_source/hdl_source/scene/scene_text_overlay.v"
$support=@('scene/scene_bram32k.v','osd/osd_font_5x7.v','osd/osd_pixel_position.v') | ForEach-Object {"$root/user_source/hdl_source/$_"}
function New-Lib([string]$name,[string]$overlayFile,[string[]]$benches){
 $lib="$out/$name/work"; New-Item -ItemType Directory "$out/$name" | Out-Null
 & "$sim/vlib.exe" $lib *> "$out/$name/library.log"
 & "$sim/vlog.exe" -work $lib @vendor *> "$out/$name/vendor.log"
 if($LASTEXITCODE){throw "Vendor compile failed: $name"}
 & "$sim/vlog.exe" -sv -work $lib $overlayFile @support @benches *> "$out/$name/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $out/$name/compile.log"}
 $lib
}
function Run-Text([string]$name,[string]$lib,[string]$folder,[string]$assets,[bool]$expectPass){
 $case="$out/$name/$folder"; New-Item -ItemType Directory $case -Force | Out-Null
 & $python -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $case "$assets/$folder"
 if($LASTEXITCODE){throw 'Vectors failed'}
 $sizes=Get-Content "$case/sizes.json" -Raw | ConvertFrom-Json
 Push-Location $case
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_m6_text glbl "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" -l "$case/text.log" -do 'run -all; quit -f' *> "$case/console.log"
  $log=Get-Content -Raw "$case/text.log"
  $pass=(-not $LASTEXITCODE) -and ($log -notmatch '\*\* (Fatal|Error):') -and ($log -match 'PASS M6 text:') -and ($log -match 'Errors: 0, Warnings: 0')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Text test failed: $case"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $name"}
}
$folders='landslide_village','debris_village','flood_village','quake_village'
$textBench="$root/diagnostics/mountain_scene/tb_m6_text.sv"
$lib=New-Lib 'text' $overlay @($textBench)
foreach($f in $folders){Run-Text 'text' $lib $f $Cards $true;Write-Output "PASS legend card $f"}
if($Legacy){foreach($f in $folders){Run-Text 'text' $lib $f $Legacy $true;Write-Output "PASS 10-segment card $f"}}
# mutants (landslide card only)
$mut="$out/mutant_src"; New-Item -ItemType Directory $mut | Out-Null
$text=Get-Content $overlay -Raw
function Mutant([string]$name,[string]$from,[string]$to){
 if(-not $text.Contains($from)){throw "Mutant $name pattern missing"}
 $file="$mut/$name.v"; $text.Replace($from,$to) | Set-Content $file -NoNewline
 $l=New-Lib "mut_$name" $file @($textBench)
 Run-Text "mut_$name" $l 'landslide_village' $Cards $false
 Write-Output "DETECTED $name"
}
Mutant 'fill_off_by_one' 'wire fill=bar_x[7:0]<=t_now;' 'wire fill=bar_x[7:0]<t_now;'
Mutant 'bar_row' 'y>=52 && y<56;' 'y>=52 && y<57;'
Mutant 'block_corner' 'pixel_x<368 && y>=32 && y<48 && (!warning' 'pixel_x<368 && y>=33 && y<48 && (!warning'
Mutant 'block_blink' '&& (!warning || frames[4]);' ';'
Mutant 'panel_edge' 'pixel_x>=348 && pixel_x<636 && y>=28 && y<60;' 'pixel_x>=348 && pixel_x<636 && y>=28 && y<59;'
Mutant 'dim_quarter' "{1'b0,video2[23:17],1'b0,video2[15:9],1'b0,video2[7:1]}" "{2'b0,video2[23:18],2'b0,video2[15:10],2'b0,video2[7:2]}"
Mutant 'title_x' "local_x={2'b0,pixel_x}-12'd376;" "local_x={2'b0,pixel_x}-12'd377;"
Mutant 'village_in_warning' 'segment_offset=warning?village_offset:title_offset;' 'segment_offset=title_offset;'
Mutant 'legend_row' 'y>=416 && y<432 && legend_length!=0' 'y>=417 && y<432 && legend_length!=0'
Mutant 'legend_band' 'y>=412 && y<436;' 'y>=413 && y<436;'
Mutant 'subtitle_band' 'y>=440 && y<464;' 'y>=441 && y<464;'
Mutant 'subtitle_row' "row=y[3:0]+4'd4;" "row=y[3:0]+4'd5;"
Mutant 'scroll_speed' "scroll<=scroll+13'd2;" "scroll<=scroll+13'd1;"
Mutant 'glyph_colour' "((cn2 && font_row[~col2]) || ascii2)?24'hffffff:" "((cn2 && font_row[~col2]) || ascii2)?24'hfffffe:"
Mutant 'warning_in_band' "descriptor==(parse_warning?4'd8:{1'b0,parse_stage,1'b1})" "descriptor=={1'b0,parse_stage,1'b1}"
Mutant 'length_5bit' 'descriptor_length<=parse_byte;' "descriptor_length<={3'd0,parse_byte[4:0]};"
Mutant 'warning_band_hidden' 'subtitle_band=BAR_ENABLE && subtitle_enable && scene_text_active && de' 'subtitle_band=BAR_ENABLE && subtitle_enable && scene_text_active && !warning && de'
Mutant 'swatch_inset' 'col1>=2 && col1<14 && row1>=2' 'col1>=1 && col1<14 && row1>=2'
Mutant 'refuge_blink' "(code[2:0]!=3'd2 || frames[5])" "(code[2:0]!=3'd2 || frames[4])"
Mutant 'swatch_colour' "3'd3:swatch_rgb=24'h8c6a3c" "3'd3:swatch_rgb=24'h8c6a3d"
Mutant 'alert_colour' "2'd2:alert_rgb=24'hff8000" "2'd2:alert_rgb=24'hff8001"
Mutant 'wide_ignored' 'wide<=LEGEND_ENABLE && parse_byte==14;' 'wide<=0;'
Mutant 'legend_stage' "descriptor==4'd10+{2'd0,parse_stage}" "descriptor==4'd10"
Mutant 'swatch_codes_rejected' "parse_byte<240 && !(LEGEND_ENABLE && parse_byte[7:3]==5'b11100))bad<=1;" "parse_byte<240)bad<=1;"
