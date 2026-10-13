param([string]$RunName='scale_s2_system1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location "$root/TD_project"
try {
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v *> "$out/controller_compile.log"
 if($LASTEXITCODE){throw 'Controller compile failed'}
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/SD/sdram.v *> "$out/wrapper_compile.log"
 if($LASTEXITCODE){throw 'Wrapper compile failed'}
 $names=@('sd_card_bmp','media_frame_cache_control','media_frame_load_control','media_frame_loader','media_frame_reader','frame_fifo_read','frame_fifo_write','media_player_control','media_display_control','mode_key_control','key_press_debounce','fat32_bmp_reader','fat32_volume_scanner','fat32_file_streamer','sd_sector_adapter','sd_sector_service','bmp_header_check','bmp24_decoder','bmp_scale_stream','bmp_sector_buffer','image_scale_nearest','color_bar','video_timing_data','video_delay')
 $rtl=$names | ForEach-Object {"../user_source/hdl_source/SD/$_.v"}
 & "$sim/vlog.exe" -sv +define+OSD_S1+OSD_S2+OSD_S3+OSD_UART+OSD_TIMESTAMP+TRANSITION_S1+PCM_S3 -work $lib "+incdir+$root/diagnostics/osd" "+incdir+$root/diagnostics/transitions" "+incdir+$root/diagnostics/pcm_audio" ../user_source/hdl_source/osd/osd_pixel_position.v ../user_source/hdl_source/osd/osd_font_5x7.v ../user_source/hdl_source/osd/osd_font_cn_16x16.v ../user_source/hdl_source/osd/osd_status_cdc.v ../user_source/hdl_source/osd/status_osd_overlay.v ../user_source/hdl_source/osd/scroll_text_overlay.v ../user_source/hdl_source/osd/osd_alpha_band.v ../user_source/hdl_source/osd/timestamp_osd.v ../user_source/hdl_source/osd/subtitle_frame_commit.v ../user_source/hdl_source/uart/subtitle_uart_controller.v ../user_source/hdl_source/uart/uart_rx_byte.v D:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v @rtl ../user_source/hdl_source/video_transition_control.v ../user_source/hdl_source/video_transition_sd_control.v ../user_source/hdl_source/video_transition_pixels.v ../user_source/hdl_source/IP/afifo_16_32_256.v ../user_source/hdl_source/IP/afifo_32_16_256.v ../user_source/hdl_source/audio/media_commit_cdc.v ../user_source/hdl_source/audio/pcm_media_tone.v ../user_source/hdl_source/audio/pcm_stream_player.v ../user_source/hdl_source/audio/fat32_pcm_stream.v ../user_source/hdl_source/audio/audio_source_mux.v ../diagnostics/single_pll/sdram_bl4_model.sv ../diagnostics/four_bank/tb_cache_system.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_cache_system -gSCALE_TEST=1 -l "$out/system.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$log=Get-Content "$out/system.log" -Raw
 if($log -notmatch 'PASS S2 origin:' -or $log -notmatch 'PASS transition system:'){throw 'Missing transition observations'}
 if($log -notmatch 'Timestamp system observations:' -or $log -notmatch 'UART system observations: 4 serial command stages'){throw 'Missing integrated OSD observations'}
 if($rc -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS cache system:' -or $log -notmatch 'Errors: 0,'){throw "Cache system failed: $out/system.log"}
 if($log -notmatch 'PCM system observations:'){throw 'Missing PCM checks'}
 $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch 'vopt-(2685|2718|2121)'})
 if($unexpected.Count){throw "Unexpected warnings: $unexpected"}
 Write-Output "PASS full cache system: $out/system.log"
}finally{Pop-Location}

