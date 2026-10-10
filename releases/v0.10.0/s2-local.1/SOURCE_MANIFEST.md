# Source and build correspondence

Production archive baseline: v0.9.1. Stage baseline: v0.10.0-s1-board.1.
Build: diagnostics/output/v010_s2_attempt3; no bit from attempt1/2.
Compared 96 current project/source files byte-for-byte with the TD input snapshot: PASS.
Archived 11 changed production files relative to v0.9.1; unchanged sources are supplied by that baseline.
Candidate demo.bit: 629624 bytes; byte-for-byte equal to this build phy_1/demo.bit.

- TD_project/demo.al
- user_source/constraints_source/pin.adc
- user_source/constraints_source/timing.sdc
- user_source/hdl_source/osd/osd_alpha_band.v
- user_source/hdl_source/osd/osd_font_cn_16x16.v
- user_source/hdl_source/osd/scroll_text_overlay.v
- user_source/hdl_source/osd/subtitle_frame_commit.v
- user_source/hdl_source/top_tf_hdmi_audio.v
- user_source/hdl_source/uart/subtitle_uart_controller.v
- user_source/hdl_source/uart/uart_event_logger.v
- user_source/hdl_source/uart/uart_rx_byte.v
