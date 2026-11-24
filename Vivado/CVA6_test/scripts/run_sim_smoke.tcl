# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-23 17:39:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Launch behavioral simulation of tb_cva6_smoke_cold_startup
#                        in batch mode.
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR [file normalize [file join $SCRIPT_DIR ".."]]
set PROJ_FILE [file join $PROJ_DIR "CVA6_test.xpr"]

open_project $PROJ_FILE

set_property top tb_cva6_smoke_cold_startup [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "====================================================================="
puts " Launching Behavioral Simulation of tb_cva6_smoke_cold_startup"
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
