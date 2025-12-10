//==============================================================================
// File: tb_bus_m2_s3_simple.sv
// Description: Simple testbench for bus_m2_s3.v verification using actual RTL
//              Tests: a) Reset, b) Single master, c) Dual masters, d) Split
//              Uses actual master_port.v and slave.v modules
//==============================================================================

`timescale 1ns / 1ps

module tb_bus_m2_s3_simple;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD = 10;
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    
    //==========================================================================
    // Testbench Signals
    //==========================================================================
    reg clk;
    reg rstn;
    
    // Master 1 device interface
    reg  [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg  [ADDR_WIDTH-1:0] m1_daddr;
    reg                   m1_dvalid;
    wire                  m1_dready;
    reg                   m1_dmode;
    
    // Master 2 device interface
    reg  [DATA_WIDTH-1:0] m2_dwdata;
    wire [DATA_WIDTH-1:0] m2_drdata;
    reg  [ADDR_WIDTH-1:0] m2_daddr;
    reg                   m2_dvalid;
    wire                  m2_dready;
    reg                   m2_dmode;
    
    // Bus signals - Master 1
    wire m1_rdata, m1_wdata, m1_mode, m1_mvalid, m1_svalid;
    wire m1_breq, m1_bgrant, m1_ack, m1_split;
    
    // Bus signals - Master 2
    wire m2_rdata, m2_wdata, m2_mode, m2_mvalid, m2_svalid;
    wire m2_breq, m2_bgrant, m2_ack, m2_split;
    
    // Bus signals - Slave 1
    wire s1_rdata, s1_wdata, s1_mode, s1_mvalid, s1_svalid, s1_ready;
    
    // Bus signals - Slave 2
    wire s2_rdata, s2_wdata, s2_mode, s2_mvalid, s2_svalid, s2_ready;
    
    // Bus signals - Slave 3 (split-capable)
    wire s3_rdata, s3_wdata, s3_mode, s3_mvalid, s3_svalid, s3_ready, s3_split;
    wire split_grant;
    
    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg [7:0] captured_m1_data;
    reg [7:0] captured_m2_data;
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    //==========================================================================
    // Master Port 1 Instantiation
    //==========================================================================
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master1 (
        .clk(clk),
        .rstn(rstn),
        .dwdata(m1_dwdata),
        .drdata(m1_drdata),
        .daddr(m1_daddr),
        .dvalid(m1_dvalid),
        .dready(m1_dready),
        .dmode(m1_dmode),
        .mrdata(m1_rdata),
        .mwdata(m1_wdata),
        .mmode(m1_mode),
        .mvalid(m1_mvalid),
        .svalid(m1_svalid),
        .mbreq(m1_breq),
        .mbgrant(m1_bgrant),
        .msplit(m1_split),
        .ack(m1_ack)
    );
    
    //==========================================================================
    // Master Port 2 Instantiation
    //==========================================================================
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master2 (
        .clk(clk),
        .rstn(rstn),
        .dwdata(m2_dwdata),
        .drdata(m2_drdata),
        .daddr(m2_daddr),
        .dvalid(m2_dvalid),
        .dready(m2_dready),
        .dmode(m2_dmode),
        .mrdata(m2_rdata),
        .mwdata(m2_wdata),
        .mmode(m2_mode),
        .mvalid(m2_mvalid),
        .svalid(m2_svalid),
        .mbreq(m2_breq),
        .mbgrant(m2_bgrant),
        .msplit(m2_split),
        .ack(m2_ack)
    );
    
    //==========================================================================
    // Bus Interconnect (DUT)
    //==========================================================================
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        // Master 1
        .m1_rdata(m1_rdata),
        .m1_wdata(m1_wdata),
        .m1_mode(m1_mode),
        .m1_mvalid(m1_mvalid),
        .m1_svalid(m1_svalid),
        .m1_breq(m1_breq),
        .m1_bgrant(m1_bgrant),
        .m1_ack(m1_ack),
        .m1_split(m1_split),
        // Master 2
        .m2_rdata(m2_rdata),
        .m2_wdata(m2_wdata),
        .m2_mode(m2_mode),
        .m2_mvalid(m2_mvalid),
        .m2_svalid(m2_svalid),
        .m2_breq(m2_breq),
        .m2_bgrant(m2_bgrant),
        .m2_ack(m2_ack),
        .m2_split(m2_split),
        // Slave 1
        .s1_rdata(s1_rdata),
        .s1_wdata(s1_wdata),
        .s1_mode(s1_mode),
        .s1_mvalid(s1_mvalid),
        .s1_svalid(s1_svalid),
        .s1_ready(s1_ready),
        // Slave 2
        .s2_rdata(s2_rdata),
        .s2_wdata(s2_wdata),
        .s2_mode(s2_mode),
        .s2_mvalid(s2_mvalid),
        .s2_svalid(s2_svalid),
        .s2_ready(s2_ready),
        // Slave 3
        .s3_rdata(s3_rdata),
        .s3_wdata(s3_wdata),
        .s3_mode(s3_mode),
        .s3_mvalid(s3_mvalid),
        .s3_svalid(s3_svalid),
        .s3_ready(s3_ready),
        .s3_split(s3_split),
        .split_grant(split_grant)
    );
    
    //==========================================================================
    // Slave 1 Instantiation (2KB, No Split)
    //==========================================================================
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(2048)
    ) slave1 (
        .clk(clk),
        .rstn(rstn),
        .srdata(s1_rdata),
        .swdata(s1_wdata),
        .smode(s1_mode),
        .svalid(s1_svalid),
        .mvalid(s1_mvalid),
        .sready(s1_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    //==========================================================================
    // Slave 2 Instantiation (4KB, No Split)
    //==========================================================================
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(4096)
    ) slave2 (
        .clk(clk),
        .rstn(rstn),
        .srdata(s2_rdata),
        .swdata(s2_wdata),
        .smode(s2_mode),
        .svalid(s2_svalid),
        .mvalid(s2_mvalid),
        .sready(s2_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    //==========================================================================
    // Slave 3 Instantiation (4KB, With Split Support)
    //==========================================================================
    slave #(
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(1),
        .MEM_SIZE(4096)
    ) slave3 (
        .clk(clk),
        .rstn(rstn),
        .srdata(s3_rdata),
        .swdata(s3_wdata),
        .smode(s3_mode),
        .svalid(s3_svalid),
        .mvalid(s3_mvalid),
        .sready(s3_ready),
        .ssplit(s3_split),
        .split_grant(split_grant)
    );
    
    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("tb_bus_m2_s3_simple.vcd");
        $dumpvars(0, tb_bus_m2_s3_simple);
    end
    
    //==========================================================================
    // Test Helper Tasks
    //==========================================================================
    
    // Initialize master device interfaces
    task init_masters;
        begin
            m1_dwdata = 8'h00;
            m1_daddr = 16'h0000;
            m1_dvalid = 1'b0;
            m1_dmode = 1'b0;
            
            m2_dwdata = 8'h00;
            m2_daddr = 16'h0000;
            m2_dvalid = 1'b0;
            m2_dmode = 1'b0;
        end
    endtask
    
    // Master 1 transaction - returns when dready goes high (transaction complete)
    task m1_transaction(input [15:0] addr, input [7:0] data, input mode);
        begin
            // Set up signals one cycle before asserting dvalid to ensure clean sampling
            m1_daddr = addr;
            m1_dwdata = data;
            m1_dmode = mode;
            $display("[TESTBENCH @%0t] m1_transaction: Set daddr=0x%h, dwdata=0x%h, dmode=%b (0=READ, 1=WRITE)", 
                     $time, addr, data, mode);
            @(posedge clk);
            
            // Now assert dvalid - master will sample on next clock
            $display("[TESTBENCH @%0t] m1_transaction: Asserting dvalid=1 (dmode=%b)", $time, m1_dmode);
            m1_dvalid = 1'b1;
            
            // Wait for dready to go low (transaction started)
            @(posedge clk);
            wait(!m1_dready);
            
            // Clear dvalid immediately to prevent re-triggering
            m1_dvalid = 1'b0;
            
            // Wait for transaction to complete (dready goes high again)
            wait(m1_dready);
            
            // Capture read data if this was a read operation
            if (!mode) begin
                @(posedge clk);  // Wait one cycle for read data to stabilize
                captured_m1_data = m1_drdata;
            end
            
            @(posedge clk);
        end
    endtask
    
    // Master 2 transaction - returns when dready goes high (transaction complete)
    task m2_transaction(input [15:0] addr, input [7:0] data, input mode);
        begin
            // Set up signals one cycle before asserting dvalid to ensure clean sampling
            m2_daddr = addr;
            m2_dwdata = data;
            m2_dmode = mode;
            @(posedge clk);
            
            // Now assert dvalid - master will sample on next clock
            m2_dvalid = 1'b1;
            
            // Wait for dready to go low (transaction started)
            @(posedge clk);
            wait(!m2_dready);
            
            // Clear dvalid immediately to prevent re-triggering
            m2_dvalid = 1'b0;
            
            // Wait for transaction to complete (dready goes high again)
            wait(m2_dready);
            
            // Capture read data if this was a read operation
            if (!mode) begin
                @(posedge clk);  // Wait one cycle for read data to stabilize
                captured_m2_data = m2_drdata;
            end
            
            @(posedge clk);
        end
    endtask
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        $display("========================================");
        $display("  bus_m2_s3.v Verification");
        $display("  Using Actual RTL Modules");
        $display("========================================");
        
        // Initialize
        init_masters();
        rstn = 1'b0;
        
        // Apply reset for 3 cycles
        repeat(3) @(posedge clk);
        rstn = 1'b1;
        
        // Wait for memory clearing to complete (largest slave is 4096 addresses)
        // Memory clearing takes MEM_SIZE cycles, so wait 4100 cycles to be safe
        $display("Waiting for slave memory clearing...");
        repeat(4100) @(posedge clk);
        $display("Memory clearing complete, starting tests...");
        
        //======================================================================
        // Test 1: Reset Test
        // Description: Verifies all bus control signals are in correct reset state
        //              Checks: bgrant=0, split=0, dready=1 for both masters
        //======================================================================
//        test_num = 1;
//        $display("\n----------------------------------------");
//        $display("Test 1: Reset Test");
//        $display("----------------------------------------");
        
//        // Check all control outputs are in reset state
//        if (m1_bgrant == 0 && m2_bgrant == 0 && m1_split == 0 && m2_split == 0 &&
//            m1_dready == 1 && m2_dready == 1) begin
//            $display("PASS: All signals properly reset");
//            $display("  - m1_bgrant = %b, m2_bgrant = %b", m1_bgrant, m2_bgrant);
//            $display("  - m1_dready = %b, m2_dready = %b", m1_dready, m2_dready);
//            $display("  - m1_split = %b, m2_split = %b", m1_split, m2_split);
//            pass_count = pass_count + 1;
//        end else begin
//            $display("ERROR: Reset state incorrect");
//            $display("  - m1_bgrant = %b (expected 0)", m1_bgrant);
//            $display("  - m2_bgrant = %b (expected 0)", m2_bgrant);
//            fail_count = fail_count + 1;
//        end
        
//        repeat(5) @(posedge clk);
        
//        //======================================================================
//        // Test 2: Single Master Request (M1 -> S1 Write + Read)
//        // Description: Tests basic single master operation with write-then-read
//        //              Verifies: Serial data transmission, memory write/read,
//        //              and bus transaction completion (dready handshake)
////        ======================================================================
//        test_num = 2;
//        $display("\n----------------------------------------");
//        $display("Test 2: Single Master Request");
//        $display("  M1 writes 0xAA to Slave 1 @ 0x0100");
//        $display("----------------------------------------");
        
//        m1_transaction(16'h0100, 8'hAA, 1'b1);  // Write to Slave 1 (device 0)
        
//        $display("  Write completed, initiating read-back...");
//        repeat(3) @(posedge clk);
        
//        // Verify write by reading back
//        m1_transaction(16'h0100, 8'h00, 1'b0);  // Read from Slave 1
        
//        // Data is captured in captured_m1_data
//        if (captured_m1_data == 8'hAA) begin
//            $display("PASS: Write and read-back successful");
//            $display("  - Written: 0xAA, Read: 0x%02h", captured_m1_data);
//            pass_count = pass_count + 1;
//        end else begin
//            $display("ERROR: Read-back data mismatch");
//            $display("  - Expected: 0xAA, Got: 0x%02h", captured_m1_data);
//            fail_count = fail_count + 1;
//        end
        
//        repeat(5) @(posedge clk);
        
//        //======================================================================
//        // Test 2a: Single Master Read (Pre-initialized Memory)
//        // Description: Tests read-only operation without prior write in this test
//        //              Reads from address that was written in Test 2 (0x0100)
//        //              Verifies: Read operation independence, data persistence
//        //======================================================================
//        test_num = test_num + 1;
//        $display("\n----------------------------------------");
//        $display("Test 2a: Single Master Read-Only");
//        $display("  M1 reads from Slave 1 @ 0x0100 (should contain 0xAA from Test 2)");
//        $display("----------------------------------------");
        
//        // Read from address that was written in Test 2
//        m1_transaction(16'h0100, 8'h00, 1'b0);  // Read from Slave 1
        
//        if (captured_m1_data == 8'hAA) begin
//            $display("PASS: Read-only operation successful");
//            $display("  - Read value: 0x%02h (data persisted from Test 2)", captured_m1_data);
//            pass_count = pass_count + 1;
//        end else begin
//            $display("ERROR: Read-only data mismatch");
//            $display("  - Expected: 0xAA (from Test 2), Got: 0x%02h", captured_m1_data);
//            fail_count = fail_count + 1;
//        end
        
//        repeat(5) @(posedge clk);
        
        //======================================================================
        // Test 3: Dual Master Request (Priority Arbitration)
        // Description: Tests concurrent requests from both masters to verify
        //              arbiter priority logic (M1 has higher priority than M2)
        //              Both masters request simultaneously, M1 gets bus first
        //======================================================================
        test_num = test_num + 1;
        $display("\n----------------------------------------");
        $display("Test 3: Dual Master Request");
        $display("  M1 writes 0x55 to S1 @ 0x0200");
        $display("  M2 writes 0x77 to S2 @ 0x1100");
        $display("  (M1 has priority over M2)");
        $display("----------------------------------------");
        
        // Both masters initiate transactions simultaneously
        fork
            m1_transaction(16'h0200, 8'h55, 1'b1);  // M1 -> S1
            m2_transaction(16'h1100, 8'h77, 1'b1);  // M2 -> S2 (device 1)
        join
        
        $display("  Both writes completed, verifying with reads...");
        repeat(3) @(posedge clk);
        
        // Verify both writes
        m1_transaction(16'h0200, 8'h00, 1'b0);  // Read M1's write
        $display("  M1 read completed: 0x%02h", captured_m1_data);
        repeat(2) @(posedge clk);
        
        m2_transaction(16'h1100, 8'h00, 1'b0);  // Read M2's write
        $display("  M2 read completed: 0x%02h", captured_m2_data);
        repeat(2) @(posedge clk);
        
        if (captured_m1_data == 8'h55 && captured_m2_data == 8'h77) begin
            $display("PASS: Both masters served with priority");
            $display("  - M1 wrote 0x55, read back: 0x%02h", captured_m1_data);
            $display("  - M2 wrote 0x77, read back: 0x%02h", captured_m2_data);
            pass_count = pass_count + 1;
        end else begin
            $display("ERROR: Data verification failed");
            $display("  - M1 expected 0x55, got: 0x%02h", captured_m1_data);
            $display("  - M2 expected 0x77, got: 0x%02h", captured_m2_data);
            fail_count = fail_count + 1;
        end
        
        repeat(5) @(posedge clk);
        
//        //======================================================================
//        // Test 4: Split Transaction (M1 -> S3)
//        // Description: Tests split transaction support for slow slaves
//        //              S3 asserts split signal during read, releasing the bus
//        //              Arbiter grants bus to S3 when ready to complete transaction
//        //              Verifies: Split handshake, bus re-arbitration, data integrity
//        //======================================================================
//        test_num = test_num + 1;
//        $display("\n----------------------------------------");
//        $display("Test 4: Split Transaction");
//        $display("  M1 writes 0xBB to S3 @ 0x2050");
//        $display("  (S3 has split support enabled)");
//        $display("----------------------------------------");
        
//        // Write to Slave 3 (split-capable)
//        $display("  Initiating write transaction to split-capable slave...");
//        m1_transaction(16'h2050, 8'hBB, 1'b1);  // Write to S3 (device 2)
        
//        $display("  Write completed (split transaction handled)");
//        repeat(5) @(posedge clk);
        
//        // Read back to verify split transaction
//        $display("  Initiating read transaction from split-capable slave...");
//        m1_transaction(16'h2050, 8'h00, 1'b0);  // Read from S3
        
//        $display("  Read completed: 0x%02h", captured_m1_data);
        
//        if (captured_m1_data == 8'hBB) begin
//            $display("PASS: Split transaction completed successfully");
//            $display("  - Written: 0xBB, Read: 0x%02h", captured_m1_data);
//            $display("  - Split signals properly handled by arbiter");
//            pass_count = pass_count + 1;
//        end else begin
//            $display("ERROR: Split transaction data mismatch");
//            $display("  - Expected: 0xBB, Got: 0x%02h", captured_m1_data);
//            fail_count = fail_count + 1;
//        end
        
//        repeat(10) @(posedge clk);
        
//        //======================================================================
//        // Test Summary
//        //======================================================================
//        $display("\n========================================");
//        $display("  Test Summary");
//        $display("========================================");
//        $display("Total Tests: %0d", test_num);
//        $display("Passed:      %0d", pass_count);
//        $display("Failed:      %0d", fail_count);
        
//        if (fail_count == 0) begin
//            $display("\n*** ALL TESTS PASSED ***\n");
//        end else begin
//            $display("\n*** SOME TESTS FAILED ***\n");
//        end
        
//        $display("Waveform saved to: tb_bus_m2_s3_simple.vcd");
//        $display("View with: gtkwave tb_bus_m2_s3_simple.vcd\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 5000);
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
