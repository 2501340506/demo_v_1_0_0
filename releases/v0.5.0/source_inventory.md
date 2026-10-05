# S2源清单与复现

候选标签v0.5.0-s2-local.1。相对S1生产RTL仅top_tf_hdmi_audio.v（两拍同步/连接）和sd_card_bmp.v（新增输入/扫描条件）变化。ADC/SDC、PLL、TD源清单不变。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName flash_boot_s2_local4 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
```

GUI复现需设置Phy/Place的hfn_opt_effort=high、opt_timing=ultra、post_place_opt=high。工程快照仍是原默认策略，单独打开demo.al默认构建不是本候选参数；实际设置随附phy_settings.cfg。

- `user_source/hdl_source/SD/switch_mode_control.v`
- `user_source/hdl_source/IP/afifo_16_32_256.v`
- `user_source/hdl_source/IP/afifo_32_16_256.v`
- `user_source/hdl_source/IP/sys_pll.v`
- `user_source/hdl_source/IP/video_pll.v`
- `user_source/hdl_source/SD/ax_debounce.v`
- `user_source/hdl_source/SD/bmp_read.v`
- `user_source/hdl_source/SD/color_bar.v`
- `user_source/hdl_source/SD/frame_fifo_read.v`
- `user_source/hdl_source/SD/frame_fifo_write.v`
- `user_source/hdl_source/SD/frame_read_write.v`
- `user_source/hdl_source/SD/sd_card_bmp.v`
- `user_source/hdl_source/SD/sd_card_cmd.v`
- `user_source/hdl_source/SD/sd_card_sec_read_write.v`
- `user_source/hdl_source/SD/sd_card_top.v`
- `user_source/hdl_source/SD/sdram.v`
- `user_source/hdl_source/SD/seg_decoder.v`
- `user_source/hdl_source/SD/seg7_panel.v`
- `user_source/hdl_source/SD/seg_scan.v`
- `user_source/hdl_source/SD/spi_master.v`
- `user_source/hdl_source/SD/video_define.v`
- `user_source/hdl_source/SD/video_delay.v`
- `user_source/hdl_source/SD/video_timing_data.v`
- `user_source/hdl_source/include/global_def.v`
- `user_source/hdl_source/include/sdr_as_ram.enc.v`
- `user_source/hdl_source/hdmi_phy_warpper.v`
- `user_source/hdl_source/lane_lvds_10_1.v`
- `user_source/hdl_source/top_tf_hdmi_audio.v`
- `user_source/hdl_source/include/sdr_init_ref.enc.v`
- `user_source/hdl_source/include/sdr_wrrd.enc.v`
- `user_source/hdl_source/SD/dual_key_event_router.v`
- `user_source/hdl_source/SD/key_gesture_control.v`
- `user_source/hdl_source/SD/media_display_control.v`
- `user_source/hdl_source/SD/media_player_control.v`
- `user_source/hdl_source/SD/media_policy.v`
- `user_source/hdl_source/SD/key_press_debounce.v`
- `user_source/hdl_source/SD/mode_key_control.v`
- `user_source/hdl_source/audio/pcm_test_tone.v`
- `user_source/hdl_source/hdmi_audio/hdmi_audio_acr_packetizer.v`
- `user_source/hdl_source/hdmi_audio/hdmi_audio_infoframe_packetizer.v`
- `user_source/hdl_source/hdmi_audio/hdmi_audio_packet_scheduler.v`
- `user_source/hdl_source/hdmi_audio/hdmi_audio_sample_packetizer.v`
- `user_source/hdl_source/hdmi_audio/hdmi_audio_symbol_core.v`
- `user_source/hdl_source/hdmi_audio/hdmi_bch8.v`
- `user_source/hdl_source/hdmi_audio/hdmi_data_island_mapper.v`
- `user_source/hdl_source/hdmi_audio/hdmi_data_island_scheduler.v`
- `user_source/hdl_source/hdmi_audio/hdmi_terc4_encoder.v`
- `user_source/hdl_source/hdmi_audio/hdmi_tmds_channel_encoder.v`
- `user_source/hdl_source/hdmi_audio/media_hdmi_audio_bridge.v`
- `user_source/hdl_source/audio/pcm_media_tone.v`
- `user_source/hdl_source/audio/media_commit_cdc.v`
- `user_source/hdl_source/reset_sync.v`
- `user_source/constraints_source/pin.adc`
- `user_source/constraints_source/timing.sdc`
