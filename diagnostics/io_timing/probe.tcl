import_device eagle_s20.db -package EG4S20BG256
open_project {D:/My_Program/anlogic_program/demo_v_0_0/TD_project/demo_Runs/phy_1/demo.prj} -noanalyze
import_db {D:/My_Program/anlogic_program/demo_v_0_0/TD_project/demo_Runs/phy_1/demo_pr.db}
puts "TIMING_COMMANDS [info commands *timing*]"
update_timing -mode final
check_timing -verbose -file baseline_check.txt
report_timing_summary -file baseline.timing
foreach cmd {report_timing report_timing_path report_pin_timing print_cover_timing_arc report_abnormal_timing_target} {
    catch {$cmd} result
    puts "$cmd RESULT $result"
}
foreach cmd {report_timing report_timing_check check_timing report_ports report_timing_summary} {
    puts "HELP $cmd"
    catch {$cmd -help} result
    puts $result
}
