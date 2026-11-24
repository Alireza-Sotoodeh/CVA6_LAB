# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 20:20:00 +03:30
# Status: NEW FILE
# Reason / Modification: Batch behavioral simulation for Suite 1
#                        (tb_cva6_branch_predict). Publishes the generated
#                        CSV trace to Vivado/CVA6/cva6_branch_trace.csv.
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize [file join $SCRIPT_DIR ".."]]
set PROJ_FILE  [file join $PROJ_DIR "CVA6_test.xpr"]
set CSV_SRC    [file join $PROJ_DIR "CVA6.sim" "sim_1" "behav" "xsim" "cva6_branch_trace.csv"]
set CSV_DST    [file join $PROJ_DIR "cva6_branch_trace.csv"]

open_project $PROJ_FILE

set_property top tb_cva6_branch_predict [get_filesets sim_1]
update_compile_order -fileset sim_1

# Remove stale traces so a failed run cannot be mistaken for a fresh result.
if {[file exists $CSV_SRC]} { file delete -force $CSV_SRC }
if {[file exists $CSV_DST]} { file delete -force $CSV_DST }

puts "====================================================================="
puts " Launching Suite 1 behavioral simulation: tb_cva6_branch_predict"
puts "====================================================================="
launch_simulation -mode behavioral

close_sim

if {[file exists $CSV_SRC]} {
    file copy -force $CSV_SRC $CSV_DST
    puts "\[INFO\] CSV trace copied to $CSV_DST"
} else {
    puts "\[WARNING\] Simulation did not produce $CSV_SRC"
}

close_project
