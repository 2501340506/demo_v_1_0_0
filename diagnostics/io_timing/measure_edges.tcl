# Caller sets project, database and clock_sdc (clock definitions only).
import_device eagle_s20.db -package EG4S20BG256
open_project $project -noanalyze
import_db $database
clear_sdc
read_sdc $clock_sdc
read_sdc [file join [file dirname [info script]] hdmi_edges.sdc]
update_timing -mode final
report_timing_exception -ep_num 30 -path_num 4 -file hdmi_edges.timing
