param([string]$RunName='four_bank_s3_regression1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location $root
try {
 [xml]$project=(Get-Content TD_project/demo.al -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $modeled=@('sys_pll_s3.v','sys_pll.v','video_pll.v','sdram.v','afifo_16_32_256.v','afifo_32_16_256.v','sdr_as_ram.enc.v','sdr_init_ref.enc.v','sdr_wrrd.enc.v')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | ForEach-Object {
  $p=$_.GetAttribute('Path');if((Split-Path $p -Leaf) -notin $modeled){Join-Path "$root/TD_project" $p}
 })
 $control=@('tb_mode_key_control','tb_dual_key_event_router','tb_media_player_control','tb_media_display_control','tb_key_gesture_control','tb_switch_mode_panel')
 $audio=@('tb_pcm_test_tone','tb_hdmi_primitives','tb_hdmi_packets','tb_hdmi_s6_phy','tb_pcm_media_tone','tb_media_commit_cdc')
 $benches=@($control+$audio | ForEach-Object {"diagnostics/history/v0.3.0/$_.sv"})
 $sd=@('tb_sd_protocol','tb_rescan_key','tb_sd_initialization','tb_sd_spi_pins')
 $benches+=@($sd | ForEach-Object {"diagnostics/sd_recovery/$_.sv"})
 $benches+=@('diagnostics/flash_boot/tb_flash_reset.sv','diagnostics/flash_boot/tb_startup.sv','diagnostics/uart_fastboot/tb_uart_event_logger.sv','diagnostics/four_bank/tb_frame_cache_control.sv','diagnostics/history/v0.3.0/tb_video_alignment.sv')
 $baseline=@()
 foreach($module in @('color_bar','video_timing_data','video_delay')){
  $source=(& git show "v0.3.0-s1-board.1:user_source/hdl_source/SD/$module.v") -join "`n"
  if($LASTEXITCODE){throw 'Cannot read video baseline'}
  $source=$source -replace '\bcolor_bar\b','s1_color_bar' -replace '\bvideo_timing_data\b','s1_video_timing_data' -replace '\bvideo_delay\b','s1_video_delay'
  $path="$out/s1_$module.v";[IO.File]::WriteAllText($path,$source,[Text.UTF8Encoding]::new($false));$baseline+=$path
 }
 & "$sim/vlog.exe" -sv -work $lib '+incdir+user_source/hdl_source/SD' @rtl @baseline @benches D:/TD/anlogic/TD6.2.1/sim_release/eg4/eg_logic_io.v D:/TD/anlogic/TD6.2.1/sim_release/eg4/eg_phy_glbl.v *> "$out/compile.log"
 if($LASTEXITCODE){throw "Regression compile failed: $out/compile.log"}
 $tests=$control+$audio+$sd+@('tb_flash_reset','tb_startup','tb_uart_event_logger','tb_frame_cache_control','tb_video_alignment')
 foreach($test in $tests){
  $options=@()
  if($test -in @('tb_hdmi_packets','tb_hdmi_s6_phy')){$options+=@('-gMEDIA=1','-gSILENCE=0')}
  if($test -eq 'tb_hdmi_s6_phy'){$options+='-gLOCAL_RESET=1'}
  Push-Location $out
  try {
   & "$sim/vsim.exe" -c -quiet -lib $lib $test glbl @options -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
   $rc=$LASTEXITCODE
  }finally{Pop-Location}
  $log=Get-Content "$out/$test.log" -Raw
  if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Regression failed: $out/$test.log"}
  Write-Output "PASS S3 $test"
 }
}finally{Pop-Location}
