# Sourced by wrapper with project, database, constraints set to absolute paths.
import_device eagle_s20.db -package EG4S20BG256
open_project $project -noanalyze
import_db $database
clear_sdc
read_sdc $constraints
update_timing -mode final
check_timing -verbose -file check_timing.txt
report_timing_summary -file timing.timing
report_timing_exception -ep_num 30 -path_num 4 -file exceptions.timing
write_verilog routed.v
