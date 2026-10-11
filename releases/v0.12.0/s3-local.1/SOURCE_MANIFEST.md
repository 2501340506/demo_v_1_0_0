Baseline: v0.11.0 / ff1c138
Build: diagnostics\output\pcm_s3_attempt5
Compared 87 project/source inputs byte for byte.
Changed production files:
TD_project/demo.al
user_source/hdl_source/SD/fat32_bmp_reader.v
user_source/hdl_source/SD/fat32_file_streamer.v
user_source/hdl_source/SD/fat32_volume_scanner.v
user_source/hdl_source/SD/sd_card_bmp.v
user_source/hdl_source/SD/sd_sector_service.v
user_source/hdl_source/audio/audio_source_mux.v
user_source/hdl_source/audio/fat32_pcm_stream.v
user_source/hdl_source/audio/pcm_stream_player.v
user_source/hdl_source/top_tf_hdmi_audio.v

Files and sizes:
BOARD_VALIDATION.md 1884
changes/TD_project/demo.al 32678
changes/user_source/hdl_source/audio/audio_source_mux.v 1053
changes/user_source/hdl_source/audio/fat32_pcm_stream.v 4049
changes/user_source/hdl_source/audio/pcm_stream_player.v 4818
changes/user_source/hdl_source/SD/fat32_bmp_reader.v 10335
changes/user_source/hdl_source/SD/fat32_file_streamer.v 9036
changes/user_source/hdl_source/SD/fat32_volume_scanner.v 14358
changes/user_source/hdl_source/SD/sd_card_bmp.v 23426
changes/user_source/hdl_source/SD/sd_sector_service.v 3793
changes/user_source/hdl_source/top_tf_hdmi_audio.v 20331
demo.bit 629624
diagnostics/pcm_audio/S3_VALIDATION.md 4820
README.md 2426
reports/audit.timing 1642346
reports/check_timing.txt 53622
reports/demo_phy.area 26436
reports/final_timing.rpt 1642346
reports/pcm_cdc.timing 2803681
reports/phy_1/td_20261011_210954.logw 1299
reports/syn_1/td_20261011_210845.logw 15653
simulation/pcm_s3_production5/tb_pcm_production.log 1370
simulation/pcm_s3_reader1/reader0_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader10_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader11_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader12_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader13_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader14_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader15_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader16_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader17_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader18_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader19_gap2_mode0.log 1344
simulation/pcm_s3_reader1/reader1_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader20_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader21_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader22_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader23_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader24_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader25_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader26_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader27_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader28_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader29_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader2_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader30_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader31_gap2_mode0.log 1347
simulation/pcm_s3_reader1/reader32_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader33_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader34_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader35_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader36_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader37_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader38_gap2_mode0.log 1346
simulation/pcm_s3_reader1/reader39_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader3_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader40_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader41_gap2_mode0.log 1348
simulation/pcm_s3_reader1/reader4_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader5_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader6_gap2_mode0.log 1345
simulation/pcm_s3_reader1/reader7_gap2_mode0.log 1343
simulation/pcm_s3_reader1/reader8_gap2_mode0.log 1343
simulation/pcm_s3_reader1/reader9_gap2_mode0.log 1345
simulation/pcm_s3_regression1/tb_dual_key_event_router.log 1302
simulation/pcm_s3_regression1/tb_flash_reset.log 1366
simulation/pcm_s3_regression1/tb_frame_cache_control.log 2283
simulation/pcm_s3_regression1/tb_hdmi_packets.log 1402
simulation/pcm_s3_regression1/tb_hdmi_primitives.log 1353
simulation/pcm_s3_regression1/tb_hdmi_s6_phy.log 1435
simulation/pcm_s3_regression1/tb_key_gesture_control.log 1568
simulation/pcm_s3_regression1/tb_media_commit_cdc.log 1309
simulation/pcm_s3_regression1/tb_media_display_control.log 1335
simulation/pcm_s3_regression1/tb_media_player_control.log 1330
simulation/pcm_s3_regression1/tb_mode_key_control.log 1274
simulation/pcm_s3_regression1/tb_pcm_media_tone.log 1353
simulation/pcm_s3_regression1/tb_pcm_test_tone.log 1502
simulation/pcm_s3_regression1/tb_rescan_key.log 1269
simulation/pcm_s3_regression1/tb_sd_initialization.log 1313
simulation/pcm_s3_regression1/tb_sd_protocol.log 1341
simulation/pcm_s3_regression1/tb_sd_spi_pins.log 3158
simulation/pcm_s3_regression1/tb_startup.log 1302
simulation/pcm_s3_regression1/tb_switch_mode_panel.log 1365
simulation/pcm_s3_regression1/tb_uart_event_logger.log 1369
simulation/pcm_s3_regression1/tb_video_alignment.log 1544
simulation/pcm_s3_system3/system.log 5501
simulation/pcm_s3_units1/tb_audio_mux.log 1225
simulation/pcm_s3_units1/tb_audio_scan.log 1267
simulation/pcm_s3_units1/tb_audio_stream.log 1306
tools/make_audio_corpus.py 856
