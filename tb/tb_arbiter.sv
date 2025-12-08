`timescale 1ns/1ps

module tb_arbiter;

    // DUT inputs
    reg clk;
    reg rstn;
    reg breq1;
    reg breq2;
    reg sready1;
    reg sready2;
    reg sreadysp;
    reg ssplit;

    // DUT outputs
    wire bgrant1;
    wire bgrant2;
    wire msel;
    wire msplit1;
    wire msplit2;
    wire split_grant;

    // Error counter
    integer errors;

    // Instantiate DUT
    arbiter dut (
        .clk        (clk),
        .rstn       (rstn),
        .breq1      (breq1),
        .breq2      (breq2),
        .sready1    (sready1),
        .sready2    (sready2),
        .sreadysp   (sreadysp),
        .ssplit     (ssplit),
        .bgrant1    (bgrant1),
        .bgrant2    (bgrant2),
        .msel       (msel),
        .msplit1    (msplit1),
        .msplit2    (msplit2),
        .split_grant(split_grant)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // Simple checker task
    task check;
        input [1023:0] msg;
        input condition;
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("[%0t] ERROR: %s", $time, msg);
            end else begin
                $display("[%0t] OK   : %s", $time, msg);
            end
        end
    endtask

    // Wait one clock and small delay to sample outputs
    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    // Apply reset task
    task apply_reset;
        begin
            $display("\n=== Applying reset ===");
            rstn      = 0;
            breq1     = 0;
            breq2     = 0;
            sready1   = 0;
            sready2   = 0;
            sreadysp  = 0;
            ssplit    = 0;
            errors    = 0;

            step; // 1 cycle in reset
            step;

            rstn = 1;
            step;

            // Check reset state
            check("After reset: no grants",
                  bgrant1 == 0 && bgrant2 == 0);
            check("After reset: msplit1, msplit2, split_grant cleared",
                  msplit1 == 0 && msplit2 == 0 && split_grant == 0);
        end
    endtask

    // Test 1: Simple priority and non split behavior
    task test_simple_priority;
        begin
            $display("\n=== Test 1: Simple priority and non split behavior ===");

            // All slaves ready
            sready1  = 1;
            sready2  = 1;
            sreadysp = 1;
            ssplit   = 0;

            // Only M1 requests
            breq1 = 1;
            breq2 = 0;
            step;

            check("M1 should get grant when only M1 requests",
                  bgrant1 == 1 && bgrant2 == 0 && msel == 0);

            // Now M2 also requests, but M1 has priority
            breq2 = 1;
            step;

            check("M1 still has grant when both request (priority)",
                  bgrant1 == 1 && bgrant2 == 0 && msel == 0);

            // Remove M1 request, M2 should now get grant
            // Note: Arbiter goes M1->IDLE first cycle, then IDLE->M2 second cycle
            breq1 = 0;
            step;  // M1 -> IDLE

            check("After M1 releases, arbiter goes to IDLE first",
                  bgrant1 == 0 && bgrant2 == 0);

            step;  // IDLE -> M2

            check("M2 gets grant on next cycle",
                  bgrant1 == 0 && bgrant2 == 1 && msel == 1);

            // Remove M2 request, arbiter should go idle
            breq2 = 0;
            step;

            check("No grants when no requests",
                  bgrant1 == 0 && bgrant2 == 0);
        end
    endtask

    // Test 2: Split on M1, M2 uses non split slaves, then resume M1
    task test_split_m1;
        begin
            $display("\n=== Test 2: Split on M1, M2 uses non split slaves, then resume M1 ===");

            // All slaves initially ready
            sready1  = 1;
            sready2  = 1;
            sreadysp = 1;
            ssplit   = 0;

            // M1 requests a transaction to split slave
            breq1 = 1;
            breq2 = 0;
            step;
            check("M1 gets grant at start of split scenario",
                  bgrant1 == 1 && bgrant2 == 0 && msel == 0);

            // Now split happens
            ssplit = 1;  // Slave says: I cannot finish, split
            step;        // next_state moves to IDLE, outputs update

            check("After split, arbiter should be idle (no grants)",
                  bgrant1 == 0 && bgrant2 == 0);
            check("M1 should have msplit1 asserted",
                  msplit1 == 1 && msplit2 == 0);

            // While split is active, M2 wants to use non split slaves
            // Keep non split slaves ready
            sready1  = 1;
            sready2  = 1;
            sreadysp = 0; // split slave not ready

            breq2 = 1;
            step;

            check("During M1 split, M2 should be able to use non split slaves",
                  bgrant1 == 0 && bgrant2 == 1 && msel == 1);

            // M2 finishes its work
            breq2 = 0;
            step;
            check("After M2 releases, arbiter back to idle (still split active)",
                  bgrant1 == 0 && bgrant2 == 0);

            // Now split slave becomes ready again
            sreadysp = 1;
            ssplit   = 0;  // slave: I am ready to complete split
            step;

            // Arbiter should reselect M1
            check("When split completes, M1 gets grant again",
                  bgrant1 == 1 && bgrant2 == 0 && msel == 0);
            
            // split_grant is generated one cycle after entering M1 state
            // (when the sequential logic processes split_owner == SM1 && !ssplit)
            step;
            check("split_grant should pulse one cycle after M1 regains grant",
                  split_grant == 1);

            // msplit1 should now be cleared (same cycle as split_grant)
            check("msplit1 should be cleared when split_grant pulses",
                  msplit1 == 0);

            // Next cycle split_grant should deassert
            step;
            check("split_grant should be deasserted after one cycle",
                  split_grant == 0);

            // M1 finally releases bus
            breq1 = 0;
            step;

            check("After M1 completes, arbiter idle",
                  bgrant1 == 0 && bgrant2 == 0);
        end
    endtask

    // Test 3: Split on M2, M1 uses non split slaves, then resume M2 (symmetric case)
    task test_split_m2;
        begin
            $display("\n=== Test 3: Split on M2, M1 uses non split slaves, then resume M2 ===");

            // Reset base conditions
            sready1  = 1;
            sready2  = 1;
            sreadysp = 1;
            ssplit   = 0;

            breq1 = 0;
            breq2 = 1;
            step;
            check("Initially M2 gets grant (M1 not requesting)",
                  bgrant1 == 0 && bgrant2 == 1 && msel == 1);

            // Split happens on M2
            ssplit = 1;
            step;

            check("After split on M2, arbiter idle",
                  bgrant1 == 0 && bgrant2 == 0);
            check("M2 should have msplit2 asserted",
                  msplit2 == 1 && msplit1 == 0);

            // Now M1 requests for non split slaves while split active
            sready1  = 1;
            sready2  = 1;
            sreadysp = 0;  // split slave not ready
            breq1    = 1;
            // Note: breq2 stays 1 - M2 still wants to complete its transaction

            step;
            check("During M2 split, M1 should get bus for non split slaves",
                  bgrant1 == 1 && bgrant2 == 0 && msel == 0);

            // M1 finishes
            breq1 = 0;
            step;
            check("Back to idle while split still active",
                  bgrant1 == 0 && bgrant2 == 0);

            // Split slave becomes ready again
            sreadysp = 1;
            ssplit   = 0;
            step;

            // Arbiter should return bus to M2
            check("When split completes, M2 gets grant again",
                  bgrant1 == 0 && bgrant2 == 1 && msel == 1);

            // split_grant is generated one cycle after entering M2 state
            step;
            check("split_grant should pulse one cycle after M2 regains grant",
                  split_grant == 1);
            check("msplit2 should be cleared when split_grant pulses",
                  msplit2 == 0);

            // Next cycle, clear pulse
            step;
            check("split_grant should clear after one cycle (M2 case)",
                  split_grant == 0);

            // M2 finishes
            breq2 = 0;
            step;
            check("After M2 completes, arbiter idle again",
                  bgrant1 == 0 && bgrant2 == 0);
        end
    endtask

    // Test 4: Basic consistency checks (never grant both, msel matches)
    task test_sanity;
        integer i;
        begin
            $display("\n=== Test 4: Sanity checks (randomized) ===");

            // Small random stimulus to verify basic properties
            for (i = 0; i < 50; i = i + 1) begin
                // Randomize inputs in a simple way
                breq1    = $random;
                breq2    = $random;
                sready1  = $random;
                sready2  = $random;
                sreadysp = $random;
                ssplit   = $random;

                step;

                // Sanity 1: never grant both masters
                check("Never grant both masters at the same time",
                      !(bgrant1 && bgrant2));

                // Sanity 2: msel reflects grant
                if (bgrant1)
                    check("When bgrant1=1, msel must be 0", msel == 0);
                if (bgrant2)
                    check("When bgrant2=1, msel must be 1", msel == 1);
            end
        end
    endtask

    // Main test sequence
    initial begin
        apply_reset;

        test_simple_priority;
        test_split_m1;
        test_split_m2;
        test_sanity;

        // Final result
        if (errors == 0) begin
            $display("\n==================================================");
            $display("ALL TESTS PASSED. No errors detected.");
            $display("==================================================\n");
        end else begin
            $display("\n==================================================");
            $display("TEST FAILED with %0d error(s).", errors);
            $display("==================================================\n");
        end

        $finish;
    end

endmodule
