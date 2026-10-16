param([string]$RunName='publicity_m4_regression01',
 [ValidateSet('unit','top','legacy_top','rgba','system','preview','m4','m3','mode','voice_top')][string]$Suite='unit',
 [string]$Card='m6_demo',[int]$Case=0,[switch]$FastDebug)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
& py -I -X utf8 "$PSScriptRoot/prepare_m4.py" $out
if($LASTEXITCODE){throw 'Preparation failed'}
if($FastDebug){
 if($Suite -ne 'voice_top'){throw 'FastDebug only supports voice_top'}
 # Diagnostic harness only: remove full-frame scaling.
 # Never select its logs as full-scale acceptance evidence.
 $bench=Get-Content -Raw "$out/tb_m4_top.sv"
 $bench=$bench.Replace('SCALE=1,AUDIO=1','SCALE=0,AUDIO=1').Replace('defparam top_dut.sd_card_bmp_m0.CLK_FREQ_HZ=1000;', 'defparam top_dut.sd_card_bmp_m0.CLK_FREQ_HZ=1000; defparam top_dut.sd_card_bmp_m0.SCALE_ENABLE=0;')
 [IO.File]::WriteAllText("$out/tb_m4_top.sv",$bench,[Text.UTF8Encoding]::new($false))
}
& py -I -X utf8 "$root/diagnostics/mountain_scene/text_vectors.py" $out "$root/tools/scenes/$Card/generated"
if($LASTEXITCODE){throw 'Vectors failed'}
$sizes=Get-Content "$out/sizes.json" -Raw | ConvertFrom-Json
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
$tests=switch($Suite){
 mode {@('tb_m4_mode')}
 m4 {@('tb_m4_player','tb_m4_auto','tb_m4_stream','tb_audio_stream','tb_pcm_stream_player','tb_audio_mux','tb_m4_metadata')}
 m3 {@('tb_m3_keys','tb_m3_identity','tb_m3_stream_start','tb_m3_stream_chain','tb_m3_scan_bounds','tb_m3_reload')}
 unit {@('tb_scenario','tb_scenario_cdc','tb_scene_fade','tb_scene_keys','tb_m5_scan','tb_m5_loader','tb_m6_text','tb_frame_cache_control','tb_transition_s1','tb_transition_wipe','tb_transition_player','tb_preview_control','tb_preview_keys','tb_preview_player','tb_adjust','tb_media_commit_cdc','tb_media_player_control','tb_pcm_production','tb_pcm_preview_rescan','tb_scenario_pcm')}
 top {@('tb_m3_top')}
 voice_top {@('tb_m4_top')}
 legacy_top {@('tb_scenario_top','tb_m6_top')}
 rgba {@('tb_rgba_sdram')}
 system {@('tb_cache_system')}
 preview {@('tb_preview_system')}
}
Push-Location "$root/TD_project"
try {
 [xml]$project=(Get-Content demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path')})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
 if($Suite -in @('rgba','system','preview')){$plain=@($plain | Where-Object {$_ -notlike '*/sd_card_top.v'})}
 & "$sim/vlog.exe" -work $lib '../user_source/ip_source/s3_single_pll/sys_pll_s3.v' *> "$out/pll.log"
 if($LASTEXITCODE){throw 'PLL compile failed'}
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' @enc *> "$out/encrypted.log"
 if($LASTEXITCODE){throw 'Encrypted compile failed'}
 $defines=switch($Suite){system {'+define+SIMULATION+OSD_S1+OSD_S2+OSD_S3+OSD_UART+OSD_TIMESTAMP+TRANSITION_S1+PCM_S3'} preview {'+define+SIMULATION+PCM_S3'} default {'+define+SIMULATION'}}
 $files=@($tests | ForEach-Object {"$out/$_.sv"})
 if($Suite -eq 'm4'){$files+=@("$PSScriptRoot/fat32_pcm_stream_m4_reference.v")}
 & "$sim/vlog.exe" -sv $defines -work $lib '+incdir+../user_source/hdl_source/include' "+incdir+$root/diagnostics/pcm_audio" "+incdir+$root/diagnostics/osd" "+incdir+$root/diagnostics/transitions" @plain "$root/diagnostics/single_pll/sdram_bl4_model.sv" @files *> "$out/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $out"}
}finally{Pop-Location}
Push-Location $out
try{
 foreach($test in $tests){
  $params=@();if($Suite -eq 'mode'){$params=@("-gCARD_CASE=$Case")}
  if($Suite -in @('rgba','system','preview')){$params=@('-gSCALE_TEST=1')}
  if($Suite -eq 'rgba'){$params+=@('-gMIXED_TEST=1')}
  if($Suite -eq 'preview'){$params+=@('-gMIXED_TEST=1','-gPREVIEW_TRANSITIONS=1','-gFAILURE_TEST=1')}
  & "$sim/vsim.exe" -c -quiet -lib $lib $test glbl @params "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content -Raw "$out/$test.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0,'){throw "Failed $test : $out"}
  $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722))' -and !($_ -match '(vopt-2241|vsim-3015)' -and $_ -match 'sys_pll_s3.v\(89\)' -and $_ -match 'load_reg')})
  if($unexpected.Count){throw "Unexpected warnings $test : $unexpected"}
  Write-Output "PASS $test"
 }
 if($Suite -eq 'm3'){
  foreach($case in 1..9){
   & "$sim/vsim.exe" -c -quiet -lib $lib tb_m3_reload glbl "-gCARD_CASE=$case" -l "$out/reload_case$case.log" -do 'run -all; quit -f' *> "$out/reload_case$case.console.log"
   $log=Get-Content -Raw "$out/reload_case$case.log"
   if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch "PASS M3 reload CARD_CASE=$case " -or $log -notmatch 'Errors: 0,'){throw "Failed reload $case : $out"}
   Write-Output "PASS reload_case$case"
  }
  foreach($extra in @('SCALE','AUDIO')){
   & "$sim/vsim.exe" -c -quiet -lib $lib tb_m3_reload glbl "-g$extra=1" -l "$out/reload_$extra.log" -do 'run -all; quit -f' *> "$out/reload_$extra.console.log"
   $log=Get-Content -Raw "$out/reload_$extra.log"
   if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M3 reload' -or $log -notmatch 'Errors: 0,'){throw "Failed reload $extra : $out"}
   Write-Output "PASS reload_$extra"
  }
 }
 if($Suite -eq 'unit'){
  foreach($gap in @(2,5)){
   & "$sim/vsim.exe" -c -quiet -lib $lib tb_m5_loader glbl "-gGAP=$gap" -l "$out/tb_m5_loader_gap$gap.log" -do 'run -all; quit -f' *> "$out/tb_m5_loader_gap$gap.console.log"
   $log=Get-Content -Raw "$out/tb_m5_loader_gap$gap.log"
   if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch "PASS M5 loader: 10 cases GAP=$gap;" -or $log -notmatch 'Errors: 0,'){throw "Failed loader GAP=$gap : $out"}
   Write-Output "PASS tb_m5_loader GAP=$gap"
  }
 }
}finally{Pop-Location}
