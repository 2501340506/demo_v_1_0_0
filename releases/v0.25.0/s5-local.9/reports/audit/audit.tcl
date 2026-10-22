import_device eagle_s20.db -package EG4S20BG256
open_project {D:/My_Program/anlogic_program/demo_v_1_0_0/diagnostics/output/lut25_hud7_td_s7/TD_project/demo_Runs/phy_1/demo.prj} -noanalyze
import_db {D:/My_Program/anlogic_program/demo_v_1_0_0/diagnostics/output/lut25_hud7_td_s7/TD_project/demo_Runs/phy_1/demo_pr.db}
update_timing -mode final
check_timing -verbose -file check_timing.txt
report_timing_summary -file audit.timing
exit