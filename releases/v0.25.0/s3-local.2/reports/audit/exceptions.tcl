import_device eagle_s20.db -package EG4S20BG256
open_project {D:/My_Program/anlogic_program/demo_v_1_0_0/diagnostics/output/lut25_narration_td_s53/TD_project/demo_Runs/phy_1/demo.prj} -noanalyze
import_db {D:/My_Program/anlogic_program/demo_v_1_0_0/diagnostics/output/lut25_narration_td_s53/TD_project/demo_Runs/phy_1/demo_pr.db}
update_timing -mode final
report_timing_exception -ep_num 30 -path_num 1 -file exceptions.timing
report_timing_path -from [get_cells {sw3_syn_4}] -ep_num 5 -path_num 1 -file sw3_sync.timing
write_verilog {D:/My_Program/anlogic_program/demo_v_1_0_0/diagnostics/output/lut25_narration_td_s53/timing_audit/physical_audit.v}
puts "SW3_PORT_COUNT=[llength [get_ports sw3]]"
puts "SW3_INPUT_REGISTER_COUNT=[llength [get_cells {sw3_syn_4}]]"
puts "UART_LOG_COUNT=[llength [get_cells -hier -quiet {*u_uart_logger*}]]"
exit