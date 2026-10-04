# S9活动源与历史保留

下列8项已从TD活动清单移除，原文件完整保留（未删除）。顶层不再实例化旧I2S/ACR/AXIS，音频PLL实例移除；官方加密HDMI核此前已不再实例化，本轮移除其清单依赖。

- `user_source/hdl_source/IP/PLL_HDMI_AUDIO.v`
- `user_source/hdl_source/hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v`
- `user_source/hdl_source/I2S_receiver.v`
- `user_source/hdl_source/audio_arc_calculate.v`
- `user_source/hdl_source/hdmi_audio_tone_i2s_64fs.v`
- `user_source/hdl_source/startup_pulse.v`
- `user_source/hdl_source/video_rgb_to_axis_640x480.v`
- `user_source/hdl_source/video_source_test.v`

系统/视频PLL只新增locked输出并连接原extlock，频率/相位/反馈参数不变。IP重新生成时须保留locked端口。SDRAM加密IP仍是存储依赖，并非HDMI加密核，继续保留。历史源码及旧阶段固定bit不变。

## 当前TD Verilog清单

- `../user_source/hdl_source/SD/switch_mode_control.v`
- `../user_source/hdl_source/IP/afifo_16_32_256.v`
- `../user_source/hdl_source/IP/afifo_32_16_256.v`
- `../user_source/hdl_source/IP/sys_pll.v`
- `../user_source/hdl_source/IP/video_pll.v`
- `../user_source/hdl_source/SD/ax_debounce.v`
- `../user_source/hdl_source/SD/bmp_read.v`
- `../user_source/hdl_source/SD/color_bar.v`
- `../user_source/hdl_source/SD/frame_fifo_read.v`
- `../user_source/hdl_source/SD/frame_fifo_write.v`
- `../user_source/hdl_source/SD/frame_read_write.v`
- `../user_source/hdl_source/SD/sd_card_bmp.v`
- `../user_source/hdl_source/SD/sd_card_cmd.v`
- `../user_source/hdl_source/SD/sd_card_sec_read_write.v`
- `../user_source/hdl_source/SD/sd_card_top.v`
- `../user_source/hdl_source/SD/sdram.v`
- `../user_source/hdl_source/SD/seg_decoder.v`
- `../user_source/hdl_source/SD/seg7_panel.v`
- `../user_source/hdl_source/SD/seg_scan.v`
- `../user_source/hdl_source/SD/spi_master.v`
- `../user_source/hdl_source/SD/video_define.v`
- `../user_source/hdl_source/SD/video_delay.v`
- `../user_source/hdl_source/SD/video_timing_data.v`
- `../user_source/hdl_source/include/global_def.v`
- `../user_source/hdl_source/include/sdr_as_ram.enc.v`
- `../user_source/hdl_source/hdmi_phy_warpper.v`
- `../user_source/hdl_source/lane_lvds_10_1.v`
- `../user_source/hdl_source/top_tf_hdmi_audio.v`
- `../user_source/hdl_source/include/sdr_init_ref.enc.v`
- `../user_source/hdl_source/include/sdr_wrrd.enc.v`
- `../user_source/hdl_source/SD/dual_key_event_router.v`
- `../user_source/hdl_source/SD/key_gesture_control.v`
- `../user_source/hdl_source/SD/media_display_control.v`
- `../user_source/hdl_source/SD/media_player_control.v`
- `../user_source/hdl_source/SD/media_policy.v`
- `../user_source/hdl_source/SD/key_press_debounce.v`
- `../user_source/hdl_source/SD/mode_key_control.v`
- `../user_source/hdl_source/audio/pcm_test_tone.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_audio_acr_packetizer.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_audio_infoframe_packetizer.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_audio_packet_scheduler.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_audio_sample_packetizer.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_audio_symbol_core.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_bch8.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_data_island_mapper.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_data_island_scheduler.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_terc4_encoder.v`
- `../user_source/hdl_source/hdmi_audio/hdmi_tmds_channel_encoder.v`
- `../user_source/hdl_source/hdmi_audio/media_hdmi_audio_bridge.v`
- `../user_source/hdl_source/audio/pcm_media_tone.v`
- `../user_source/hdl_source/audio/media_commit_cdc.v`
- `../user_source/hdl_source/reset_sync.v`
