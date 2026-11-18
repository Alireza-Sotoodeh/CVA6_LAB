```verilog
// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-10 16:15:00 +03:30 (update the time and date)
// Status: NEW FILE | MODIFIED FILE
// Reason / Modification: <Detailed explanation of changes or purpose>
// ============================================================================

`timescale 1ns / 1ps

module tb_generic;

    timeunit      1ns;
    timeprecision 1ps;

    // ========================================================================
    // 1. Configuration and Test Contract
    // ========================================================================

    localparam time         CLK_PERIOD       = 10ns;
    localparam time         WATCHDOG_TIMEOUT = 1ms;
    localparam int unsigned RESET_CYCLES     = 5;
    localparam bit          ENABLE_CSV       = 1'b1;

    // DUT-SPECIFIC: document before implementing the tests.
    //
    // - Clock domain(s):
    // - Reset polarity and behavior:
    // - Input/output protocol:
    // - Input driving edge:
    // - Output sampling edge and sampling semantics:
    // - Expected behavior:
    // - Maximum operation latency:
    // - Required test scenarios:
    //
    // Default infrastructure assumes:
    // - One free-running clock.
    // - Active-low reset.
    // - Reset release on negedge.
    // - CSV samples pre-NBA values at posedge.
    //
    // Adapt these assumptions to the actual DUT specification.

    // ========================================================================
    // 2. Signals, DUT Instantiation, and Debug Probes
    // ========================================================================

    logic clk;
    logic rst_n;

    // DUT-SPECIFIC: declare DUT interface signals here.

    // DUT-SPECIFIC: instantiate the DUT using explicit named port mapping.

    // DUT-SPECIFIC: add important internal debug probes as needed.
    //
    // - Inspect actual RTL before adding hierarchical references.
    // - Verify signal names, widths, and hierarchy paths.
    // - Preserve four-state values so X/Z remain visible.
    // - Use internal probes for debug, not as the reference model.

    // ========================================================================
    // 3. Control and Accounting
    // ========================================================================

    int          random_seed      = 1;
    int          log_file         = 0;

    int unsigned cycle_count      = 0;
    int unsigned check_count      = 0;
    int unsigned error_count      = 0;

    // Indicates end of execution, NOT verification success.
    bit          test_completed   = 1'b0;
    bit          watchdog_tripped = 1'b0;

    // DUT-SPECIFIC: add useful debug context when applicable.
    //
    // Examples:
    // - scenario_id
    // - transaction_id
    // - check_active
    // - expected_value
    // - sampled_actual_value
    //
    // Define when each context value becomes valid and when it is cleared.

    // ========================================================================
    // 4. Clock and CSV Telemetry
    // ========================================================================

    initial begin : clock_generation
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // CSV LOGGING REQUIREMENTS:
    //
    // Prioritize debug visibility over CSV file size.
    // Do not omit important signals merely to reduce the number of columns
    // or the size of the trace.
    //
    // The goal is to make module behavior and failures easy to reconstruct
    // from the CSV, with minimal reliance on additional waveform inspection.
    //
    // DUT-SPECIFIC: include as many diagnostically useful signals as possible,
    // using the actual DUT interface and verified RTL hierarchy:
    //
    // - Time, cycle count, reset, scenario ID, and transaction ID.
    // - All relevant DUT inputs and outputs.
    // - Request/response valid, ready, enable, acknowledge, busy, and done.
    // - Payloads, addresses, commands, opcodes, and byte enables.
    // - FSM current state and next state.
    // - Important counters, timers, indexes, pointers, and occupancy levels.
    // - FIFO full/empty flags and read/write activity.
    // - Pipeline valid bits, stalls, flushes, and stage control signals.
    // - Important intermediate datapath values and result registers.
    // - Memory enables, addresses, write data, and read data.
    // - Arbitration selections, grants, and resource ownership.
    // - Error, overflow, underflow, interrupt, and exception flags.
    // - Expected/actual checker values and check-active indicators,
    //   where they can be sampled consistently with the logged transaction.
    //
    // IMPLEMENTATION RULES:
    //
    // - Add only signals that actually exist; never invent hierarchy paths.
    // - Verify internal signal names, widths, and meaning from the RTL.
    // - Use clear, unique column names and meaningful numeric formats.
    // - Keep CSV header order and row argument order exactly consistent.
    // - Preserve X/Z visibility; avoid two-state casts on debug probes.
    // - Log every clock edge handled by this logger, including idle,
    //   stalled, and reset cycles.
    // - This logger samples pre-NBA values at posedge.
    // - Avoid racing logger context updates against this sampling edge.
    // - For post-NBA or other-clock observations, add explicitly identified
    //   sampling records or separate logs.
    // - Do not silently mix different sampling semantics.
    // - For large memories, prioritize access activity and relevant locations
    //   rather than indiscriminately dumping every memory word each cycle.

    always @(posedge clk) begin : telemetry
        if (!test_completed) begin

            // Active cycle counting is independent of CSV logging.
            // Reset cycles are logged but not counted as active cycles.
            if (rst_n === 1'b1)
                cycle_count++;

            if (log_file != 0) begin
                // DUT-SPECIFIC:
                // Expand this row using the logging requirements above.
                // Update the CSV header in main to match exactly.
                $fdisplay(
                    log_file,
                    "%0t,%0d,%b",
                    $time,
                    cycle_count,
                    rst_n
                );
            end
        end
    end

    // ========================================================================
    // 5. Initialization and Reset
    // ========================================================================

    task automatic initialize_inputs();
        // DUT-SPECIFIC:
        // Assign known, inactive values to every driven DUT input.
    endtask

    task automatic apply_reset();
        rst_n = 1'b0;
        initialize_inputs();

        repeat (RESET_CYCLES) @(posedge clk);

        // Release reset away from the default DUT sampling edge.
        @(negedge clk);
        rst_n = 1'b1;

        // DUT-SPECIFIC: add recovery cycles if required.
    endtask

    // ========================================================================
    // 6. Driver, Reference Model, and Checks
    // ========================================================================

    // DUT-SPECIFIC: add only the helpers required by the design.
    //
    // Examples:
    // - Drive inputs or start an operation.
    // - Compute expected results from the specification.
    // - Wait for completion with a bounded timeout.
    // - Compare actual behavior against expected behavior.
    //
    // Rules:
    // - Avoid driving inputs on the DUT sampling edge.
    // - Define pre-NBA versus post-NBA sampling explicitly.
    // - Derive expected behavior from the specification, not DUT internals.
    // - Bound protocol waits; keep the global watchdog as a backstop.
    // - Record failures instead of calling $finish/$fatal inside helpers.
    // - Stop unsafe continuation after timeout or protocol failure.
    // - Include useful context in errors: scenario, transaction, inputs,
    //   expected result, actual result, and timeout phase where applicable.

    // A 0, X, or Z condition is treated as a failed check.
    task automatic check_condition(
        input logic  condition,
        input string description
    );
        check_count++;

        if (condition !== 1'b1) begin
            error_count++;

            $display(
                "[ERROR] t=%0t %s",
                $time,
                description
            );
        end
    endtask

    // Record an execution/protocol error without counting a result check.
    task automatic report_error(input string description);
        error_count++;

        $display(
            "[ERROR] t=%0t %s",
            $time,
            description
        );
    endtask

    // ========================================================================
    // 7. Test Scenarios
    // ========================================================================

    task automatic run_tests();

        // DUT-SPECIFIC: implement applicable scenarios.
        //
        // 1. Reset / initial-state behavior
        // 2. Basic nominal operation
        // 3. Boundary and corner cases
        // 4. Randomized cases, if useful
        // 5. Final pending-output / idle checks
        //
        // Use check_condition(...) for actual verification.
        // Do not add dummy checks to satisfy check_count > 0.
        //
        // Return only after all expected outputs have been checked.
        // If execution is aborted early, record an error before returning.
        //
        // Do not assign test_completed here.
        // The main block owns simulation completion.

    endtask

    // ========================================================================
    // 8. Main Execution, Watchdog, and Termination
    // ========================================================================

    initial begin : main
        $timeformat(-9, 0, " ns", 12);

        rst_n          = 1'b0;
        test_completed = 1'b0;
        initialize_inputs();

        // A. Seed configuration
        if ($value$plusargs("seed=%d", random_seed)) begin
            $display("[TB] Using command-line seed.");
        end

        $display("[TB] seed=%0d", random_seed);

        // B. Optional CSV logging
        if (ENABLE_CSV) begin
            log_file = $fopen("simulation_trace.csv", "w");

            if (log_file == 0) begin
                report_error("Cannot open simulation_trace.csv");
            end
            else begin
                // DUT-SPECIFIC:
                // Expand this header to match the telemetry row exactly.
                $fdisplay(log_file, "Time,Cycle,ResetN");
            end
        end

        // C. Guarded test execution
        if (error_count == 0) begin
            fork
                begin : test_thread
                    process test_process;

                    // Seed the process that generates test stimulus.
                    test_process = process::self();
                    test_process.srandom(random_seed);

                    apply_reset();
                    run_tests();

                    // Normal termination away from posedge telemetry.
                    @(negedge clk);
                end

                begin : watchdog_thread
                    // Time-based protection, independent of clock activity.
                    #(WATCHDOG_TIMEOUT);

                    watchdog_tripped = 1'b1;

                    $display(
                        "[ERROR] Global watchdog expired at %0t",
                        $time
                    );
                end
            join_any

            // Stop the remaining test/watchdog branch and its descendants.
            disable fork;
        end

        // D. Mark execution complete on every controlled exit path.
        // This flag alone does not stop the simulator.
        test_completed = 1'b1;

        // Advance one precision step before simulation termination
        // so the completion transition can be captured in the waveform.
        #1step;

        // E. Close telemetry
        if (log_file != 0) begin
            $fclose(log_file);
            log_file = 0;
        end

        // F. Verification summary
        $display("=======================================================");
        $display(" VERIFICATION SUMMARY");
        $display("=======================================================");
        $display(" Seed              : %0d", random_seed);
        $display(" Simulation time   : %0t", $time);
        $display(" Active cycles     : %0d", cycle_count);
        $display(" Checks            : %0d", check_count);
        $display(" Errors            : %0d", error_count);
        $display(" Test completed    : %0b", test_completed);
        $display(" Watchdog tripped  : %0b", watchdog_tripped);
        $display("=======================================================");

        // G. Terminate simulation, including during Vivado Run All.
        if (watchdog_tripped || error_count > 0 || check_count == 0) begin
            $display("== TEST FAILED ==");
            $fatal(1, "Verification criteria not met.");
        end
        else begin
            $display("== TEST PASSED ==");
            $finish;
        end
    end

endmodule

```