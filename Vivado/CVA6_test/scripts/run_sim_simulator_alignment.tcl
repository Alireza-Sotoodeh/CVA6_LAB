# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 17:58:00 +03:30
# Status: NEW FILE
# Reason / Modification: Batch behavioral simulation automation for unified
#                        hardware alignment testbench (tb_cva6_simulator_alignment).
#                        Compiles, elaborates, and runs Vivado XSIM behavioral
#                        simulation and publishes cva6_simulator_alignment_trace.csv.
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize [file join $SCRIPT_DIR ".."]]
set PROJ_FILE  [file join $PROJ_DIR "CVA6_test.xpr"]
set TB_FILE    [file join $PROJ_DIR "sim" "tb_cva6_simulator_alignment.sv"]
set CSV_SRC    [file join $PROJ_DIR "CVA6.sim" "sim_1" "behav" "xsim" "cva6_simulator_alignment_trace.csv"]
set CSV_DST    [file join $PROJ_DIR "cva6_simulator_alignment_trace.csv"]

open_project $PROJ_FILE

if {[get_files -quiet $TB_FILE] eq ""} {
    add_files -fileset sim_1 -norecurse $TB_FILE
    puts "\[INFO\] Added $TB_FILE to sim_1"
}

set_property top tb_cva6_simulator_alignment [get_filesets sim_1]
update_compile_order -fileset sim_1

# Remove stale traces so a failed run cannot be mistaken for a fresh result.
if {[file exists $CSV_SRC]} { file delete -force $CSV_SRC }
if {[file exists $CSV_DST]} { file delete -force $CSV_DST }

puts "====================================================================="
puts " Launching Hardware Alignment behavioral simulation: tb_cva6_simulator_alignment"
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
