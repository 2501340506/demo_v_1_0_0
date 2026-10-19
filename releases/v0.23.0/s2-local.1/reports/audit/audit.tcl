import_device eagle_s20.db -package EG4S20BG256
open_project {E:/form/demo_v_0_0/demo_v_0_0/diagnostics/output/fast_start_td23/TD_project/demo_Runs/phy_1/demo.prj} -noanalyze
import_db {E:/form/demo_v_0_0/demo_v_0_0/diagnostics/output/fast_start_td23/TD_project/demo_Runs/phy_1/demo_pr.db}
update_timing -mode final
check_timing -verbose -file check_timing.txt
report_timing_summary -file audit.timing
exit