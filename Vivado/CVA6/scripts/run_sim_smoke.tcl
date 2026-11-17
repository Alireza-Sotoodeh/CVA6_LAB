# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-17 23:45:00 +03:30
# Status: NEW FILE
# Reason / Modification: Launch behavioral simulation of tb_cva6 smoke test in batch mode
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR [file normalize [file join $SCRIPT_DIR ".."]]
set PROJ_FILE [file join $PROJ_DIR "CVA6.xpr"]

open_project $PROJ_FILE

set_property top tb_cva6 [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "====================================================================="
puts " Launching Behavioral Simulation of tb_cva6"
puts "====================================================================="
launch_simulation -mode behavioral

puts "====================================================================="
puts " Running Simulation to Completion"
puts "====================================================================="
run all

puts "====================================================================="
puts " Closing Simulation and Project"
puts "====================================================================="
close_sim
close_project
