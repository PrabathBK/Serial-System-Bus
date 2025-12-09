`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: tb_addr_decoder
// Description: Testbench for address decoder module
//              Tests Assignment Task 3 requirements:
//              - Address decoder verification
//              - 3 slaves support
//              - Address mapping (Device 0/1/2 -> Slave 1/2/3)
//              - Reset test
//              - Slave select functionality
//
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//-----------------------------------------------------------------------------

module tb_addr_decoder;

    // Parameters
    parameter ADDR_WIDTH = 16;
    parameter DEVICE_ADDR_WIDTH = 4;
    parameter CLK_PERIOD = 10;  // 100 MHz

    // DUT inputs
    reg clk;
    reg rstn;
    reg mwdata;
    reg mvalid;
    reg ssplit;
    reg split_grant;
    reg sready1;
    reg sready2;
    reg sready3;

    // DUT outputs
    wire mvalid1;
    wire mvalid2;
    wire mvalid3;
    wire [1:0] ssel;
    wire ack;

    // Test variables
    integer errors;
    integer test_num;

    // Instantiate DUT
    addr_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEVICE_ADDR_WIDTH(DEVICE_ADDR_WIDTH)
    ) dut (
        .clk        (clk),
        .rstn       (rstn),
        .mwdata     (mwdata),
        .mvalid     (mvalid),
        .ssplit     (ssplit),
        .split_grant(split_grant),
        .sready1    (sready1),
        .sready2    (sready2),
        .sready3    (sready3),
        .mvalid1    (mvalid1),
        .mvalid2    (mvalid2),
        .mvalid3    (mvalid3),
        .ssel       (ssel),
        .ack        (ack)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Timeout!");
        $finish;
    end

    //-------------------------------------------------------------------------
    // Helper tasks
    //-------------------------------------------------------------------------

    // Check condition and report
    task check;
        input [1023:0] msg;
        input condition;
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("[%0t] ERROR: %s", $time, msg);
            end else begin
                $display("[%0t] PASS : %s", $time, msg);
            end
        end
    endtask

    // Wait one clock cycle with small delay for output sampling
    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    // Send device address serially (LSB first, 4 bits)
    task send_device_addr;
        input [DEVICE_ADDR_WIDTH-1:0] addr;
        integer i;
        begin
            // First bit is sent when mvalid goes high (IDLE state captures it)
            mwdata = addr[0];
            mvalid = 1;
            step;  // Move to ADDR state
            
            // Send remaining bits (bits 1, 2, 3)
            for (i = 1; i < DEVICE_ADDR_WIDTH; i = i + 1) begin
                mwdata = addr[i];
                step;
            end
            // After 4 cycles, should be in CONNECT state
        end
    endtask

    // Apply reset and initialize signals
    task apply_reset;
        begin
            $display("\n=== Applying Reset ===");
            rstn = 0;
            mwdata = 0;
            mvalid = 0;
            ssplit = 0;
            split_grant = 0;
            sready1 = 0;
            sready2 = 0;
            sready3 = 0;
            errors = 0;

            step;
            step;

            rstn = 1;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 1: Reset Test
    //-------------------------------------------------------------------------
    task test_reset;
        begin
            test_num = 1;
            $display("\n=== Test %0d: Reset Test ===", test_num);
            
            apply_reset;

            // Check all outputs are in reset state
            check("After reset: ssel should be 0",
                  ssel == 2'b00);
            check("After reset: ack should be 0",
                  ack == 0);
            check("After reset: mvalid1 should be 0",
                  mvalid1 == 0);
            check("After reset: mvalid2 should be 0",
                  mvalid2 == 0);
            check("After reset: mvalid3 should be 0",
                  mvalid3 == 0);
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 2: Address Mapping - Slave 1 (Device 0, addr=0x0)
    //-------------------------------------------------------------------------
    task test_slave1_select;
        begin
            test_num = 2;
            $display("\n=== Test %0d: Address Mapping - Slave 1 (Device 0) ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Send device address 0 (4'b0000) for Slave 1
            send_device_addr(4'b0000);
            
            // Now in CONNECT state, check ack (combinational)
            check("Slave 1: ack should be asserted",
                  ack == 1);
            
            // Keep mvalid high to move to WAIT state
            // ssel is registered, so check after one more clock
            step;
            
            // In WAIT state, ssel is now updated
            check("Slave 1: ssel should be 2'b00",
                  ssel == 2'b00);
            
            // Check mvalid routing
            check("Slave 1: mvalid1 should be 1",
                  mvalid1 == 1);
            check("Slave 1: mvalid2 should be 0",
                  mvalid2 == 0);
            check("Slave 1: mvalid3 should be 0",
                  mvalid3 == 0);
            
            // Complete transaction - slave becomes ready (goes back to IDLE)
            mvalid = 0;
            step;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 3: Address Mapping - Slave 2 (Device 1, addr=0x1)
    //-------------------------------------------------------------------------
    task test_slave2_select;
        begin
            test_num = 3;
            $display("\n=== Test %0d: Address Mapping - Slave 2 (Device 1) ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Send device address 1 (4'b0001) for Slave 2
            send_device_addr(4'b0001);
            
            // Now in CONNECT state, check ack (combinational)
            check("Slave 2: ack should be asserted",
                  ack == 1);
            
            // Keep mvalid high to move to WAIT state
            // ssel is registered, so check after one more clock
            step;
            
            // In WAIT state, ssel is now updated
            check("Slave 2: ssel should be 2'b01",
                  ssel == 2'b01);
            
            // Check mvalid routing
            check("Slave 2: mvalid1 should be 0",
                  mvalid1 == 0);
            check("Slave 2: mvalid2 should be 1",
                  mvalid2 == 1);
            check("Slave 2: mvalid3 should be 0",
                  mvalid3 == 0);
            
            // Complete transaction
            mvalid = 0;
            step;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 4: Address Mapping - Slave 3 (Device 2, addr=0x2) - Split support
    //-------------------------------------------------------------------------
    task test_slave3_select;
        begin
            test_num = 4;
            $display("\n=== Test %0d: Address Mapping - Slave 3 (Device 2 - Split Support) ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Send device address 2 (4'b0010) for Slave 3
            send_device_addr(4'b0010);
            
            // Now in CONNECT state, check ack (combinational)
            check("Slave 3: ack should be asserted",
                  ack == 1);
            
            // Keep mvalid high to move to WAIT state
            // ssel is registered, so check after one more clock
            step;
            
            // In WAIT state, ssel is now updated
            check("Slave 3: ssel should be 2'b10",
                  ssel == 2'b10);
            
            // Check mvalid routing
            check("Slave 3: mvalid1 should be 0",
                  mvalid1 == 0);
            check("Slave 3: mvalid2 should be 0",
                  mvalid2 == 0);
            check("Slave 3: mvalid3 should be 1",
                  mvalid3 == 1);
            
            // Complete transaction
            mvalid = 0;
            step;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 5: Invalid Address (Device 3 - out of range)
    //-------------------------------------------------------------------------
    task test_invalid_address;
        begin
            test_num = 5;
            $display("\n=== Test %0d: Invalid Address (Device 3 - Out of Range) ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Send device address 3 (4'b0011) - invalid, only 0-2 are valid
            send_device_addr(4'b0011);
            
            // In CONNECT state, check ack is NOT asserted (invalid address)
            check("Invalid addr: ack should NOT be asserted",
                  ack == 0);
            
            // Should return to IDLE
            step;
            check("Invalid addr: should return to IDLE, no mvalid signals",
                  mvalid1 == 0 && mvalid2 == 0 && mvalid3 == 0);
            
            mvalid = 0;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 6: Slave Not Ready - No ACK
    //-------------------------------------------------------------------------
    task test_slave_not_ready;
        begin
            test_num = 6;
            $display("\n=== Test %0d: Slave Not Ready - No ACK ===", test_num);
            
            apply_reset;
            
            // Only slaves 2 and 3 ready, slave 1 NOT ready
            sready1 = 0;
            sready2 = 1;
            sready3 = 1;
            
            // Try to address Slave 1 (Device 0)
            send_device_addr(4'b0000);
            
            // Slave 1 not ready, should NOT ack (combinational check)
            check("Slave 1 not ready: ack should NOT be asserted",
                  ack == 0);
            
            // State machine goes CONNECT -> IDLE (since slave_addr_valid is 0)
            // Need to deassert mvalid to allow transition
            mvalid = 0;
            step;
            step;  // Give time to return to IDLE
            
            check("Slave not ready: should return to IDLE",
                  mvalid1 == 0 && mvalid2 == 0 && mvalid3 == 0);
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 7: Split Transaction Support
    //-------------------------------------------------------------------------
    task test_split_transaction;
        begin
            test_num = 7;
            $display("\n=== Test %0d: Split Transaction Support ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Connect to Slave 3 (split-capable)
            send_device_addr(4'b0010);
            
            check("Split test: ack should be asserted for Slave 3",
                  ack == 1);
            
            // Move to WAIT state
            step;
            
            check("Split test: mvalid3 should be active",
                  mvalid3 == 1);
            
            // Slave issues split - this causes transition to IDLE
            ssplit = 1;
            step;
            
            // In IDLE now, mvalid is 0 since slave_en cleared
            ssplit = 0;
            mvalid = 0;
            step;  // One more cycle to stabilize
            
            // Should be in IDLE
            check("After split: should be in IDLE (no mvalid)",
                  mvalid1 == 0 && mvalid2 == 0 && mvalid3 == 0);
            
            // Now split_grant comes from arbiter
            split_grant = 1;
            step;
            
            // Should transition to WAIT state with saved slave address
            split_grant = 0;
            step;
            
            check("After split_grant: ssel should be 2'b10 (Slave 3)",
                  ssel == 2'b10);
            
            step;
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 8: Sequential Slave Selection
    //-------------------------------------------------------------------------
    task test_sequential_slaves;
        begin
            test_num = 8;
            $display("\n=== Test %0d: Sequential Slave Selection ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Transaction to Slave 1
            $display("  Selecting Slave 1...");
            send_device_addr(4'b0000);
            step;  // WAIT - ssel updated
            check("Seq: Slave 1 selected (ssel=00)", ssel == 2'b00);
            mvalid = 0;
            step;  // Back to IDLE
            step;
            
            // Transaction to Slave 2
            $display("  Selecting Slave 2...");
            send_device_addr(4'b0001);
            step;  // WAIT - ssel updated
            check("Seq: Slave 2 selected (ssel=01)", ssel == 2'b01);
            mvalid = 0;
            step;  // Back to IDLE
            step;
            
            // Transaction to Slave 3
            $display("  Selecting Slave 3...");
            send_device_addr(4'b0010);
            step;  // WAIT - ssel updated
            check("Seq: Slave 3 selected (ssel=10)", ssel == 2'b10);
            mvalid = 0;
            step;  // Back to IDLE
            step;
        end
    endtask

    //-------------------------------------------------------------------------
    // Test 9: Reset During Transaction
    //-------------------------------------------------------------------------
    task test_reset_during_transaction;
        begin
            test_num = 9;
            $display("\n=== Test %0d: Reset During Transaction ===", test_num);
            
            apply_reset;
            
            // All slaves ready
            sready1 = 1;
            sready2 = 1;
            sready3 = 1;
            
            // Start addressing Slave 2
            mwdata = 1;  // LSB of addr 1
            mvalid = 1;
            step;
            
            // Mid-transaction, apply reset
            rstn = 0;
            step;
            
            // Check reset clears state
            check("Reset during tx: ssel should be 0", ssel == 2'b00);
            check("Reset during tx: no mvalid outputs",
                  mvalid1 == 0 && mvalid2 == 0 && mvalid3 == 0);
            
            rstn = 1;
            mvalid = 0;
            step;
            
            // Should be able to start new transaction
            check("After reset recovery: decoder should be in IDLE",
                  ack == 0 && mvalid1 == 0 && mvalid2 == 0 && mvalid3 == 0);
        end
    endtask

    //-------------------------------------------------------------------------
    // Main Test Sequence
    //-------------------------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("Address Decoder Testbench - Assignment Task 3");
        $display("==================================================");
        $display("Testing:");
        $display("  - Address decoder verification");
        $display("  - 3 slaves support");
        $display("  - Address mapping");
        $display("  - Reset test");
        $display("  - Slave select functionality");
        $display("==================================================");

        // Run all tests
        test_reset;
        test_slave1_select;
        test_slave2_select;
        test_slave3_select;
        test_invalid_address;
        test_slave_not_ready;
        test_split_transaction;
        test_sequential_slaves;
        test_reset_during_transaction;

        // Final results
        $display("\n==================================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED. No errors detected.");
        end else begin
            $display("TESTS FAILED with %0d error(s).", errors);
        end
        $display("==================================================\n");

        $finish;
    end

endmodule
