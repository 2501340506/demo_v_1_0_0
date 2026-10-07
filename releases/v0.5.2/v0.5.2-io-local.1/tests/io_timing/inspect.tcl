import_device eagle_s20.db -package EG4S20BG256
open_project {D:/My_Program/anlogic_program/demo_v_0_0/TD_project/demo_Runs/phy_1/demo.prj} -noanalyze
import_db {D:/My_Program/anlogic_program/demo_v_0_0/TD_project/demo_Runs/phy_1/demo_pr.db}
clear_sdc
read_sdc {../../user_source/constraints_source/timing.sdc}
read_sdc measure.sdc
update_timing -mode final
report_timing_summary -ep_num 30 -path_num 4 -file measured.timing
report_timing_exception -file measured_exceptions.timing
report_timing_path -to {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P sd_dclk sd_mosi sd_ncs} -ep_num 30 -path_num 8 -file measured_outputs.timing
report_timing_path -from {sd_miso} -ep_num 10 -path_num 8 -file measured_input.timing
write_verilog baseline_netlist.v
report_cells {u_pcm_clock/mult0_syn_4} -connection
report_cells {sd_card_bmp_m0/auto_blocked_reg_syn_43} -connection
puts "STAT [get_timing_stat]"
