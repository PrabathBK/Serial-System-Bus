//==============================================================================
// File: simple_read_test.sv
// Description: Simple testbench to debug Master 2 read data issue
//              Tests sequential writes and reads to verify data integrity
//==============================================================================

`timescale 1ns/1ps

module simple_read_test;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz

    //--------------------------------------------------------------------------
    // Global Signals
    //--------------------------------------------------------------------------
    reg clk;
    reg rstn;

    //--------------------------------------------------------------------------
    // Master 1 Device Interface
    //--------------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0]   d1_wdata;
    wire [DATA_WIDTH-1:0]   d1_rdata;
    reg  [ADDR_WIDTH-1:0]   d1_addr;
    reg                     d1_valid;
    wire                    d1_ready;
    reg                     d1_mode;        // 0 - read, 1 - write

    //--------------------------------------------------------------------------
    // Master 2 Device Interface
    //--------------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0]   d2_wdata;
    wire [DATA_WIDTH-1:0]   d2_rdata;
    reg  [ADDR_WIDTH-1:0]   d2_addr;
    reg                     d2_valid;
    wire                    d2_ready;
    reg                     d2_mode;        // 0 - read, 1 - write

    //--------------------------------------------------------------------------
    // Bus Signals - Master 1
    //--------------------------------------------------------------------------
    wire m1_rdata;
    wire m1_wdata;
    wire m1_mode;
    wire m1_mvalid;
    wire m1_svalid;
    wire m1_breq;
    wire m1_bgrant;
    wire m1_ack;
    wire m1_split;

    //--------------------------------------------------------------------------
    // Bus Signals - Master 2
    //--------------------------------------------------------------------------
    wire m2_rdata;
    wire m2_wdata;
    wire m2_mode;
    wire m2_mvalid;
    wire m2_svalid;
    wire m2_breq;
    wire m2_bgrant;
    wire m2_ack;
    wire m2_split;

    //--------------------------------------------------------------------------
    // Bus Signals - Slave 1
    //--------------------------------------------------------------------------
    wire s1_rdata;
    wire s1_wdata;
    wire s1_mode;
    wire s1_mvalid;
    wire s1_svalid;
    wire s1_ready;

    //--------------------------------------------------------------------------
    // Bus Signals - Slave 2
    //--------------------------------------------------------------------------
    wire s2_rdata;
    wire s2_wdata;
    wire s2_mode;
    wire s2_mvalid;
    wire s2_svalid;
    wire s2_ready;

    //--------------------------------------------------------------------------
    // Bus Signals - Slave 3 (Split-capable)
    //--------------------------------------------------------------------------
    wire s3_rdata;
    wire s3_wdata;
    wire s3_mode;
    wire s3_mvalid;
    wire s3_svalid;
    wire s3_ready;
    wire s3_split;

    //--------------------------------------------------------------------------
    // Split Transaction Control
    //--------------------------------------------------------------------------
    wire split_grant;

    //--------------------------------------------------------------------------
    // Testbench Control Variables
    //--------------------------------------------------------------------------
    integer test_count = 0;
    integer error_count = 0;
    
    // Combined slave ready signal
    wire s_ready;
    assign s_ready = s1_ready & s2_ready & s3_ready;

    //==========================================================================
    // DUT Instantiations
    //==========================================================================

    //--------------------------------------------------------------------------
    // Master Port 1
    //--------------------------------------------------------------------------
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master1 (
        .clk(clk),
        .rstn(rstn),
        .dwdata(d1_wdata),
        .drdata(d1_rdata),
        .daddr(d1_addr),
        .dvalid(d1_valid),
        .dready(d1_ready),
        .dmode(d1_mode),
        .mrdata(m1_rdata),
        .mwdata(m1_wdata),
        .mmode(m1_mode),
        .mvalid(m1_mvalid),
        .svalid(m1_svalid),
        .mbreq(m1_breq),
        .mbgrant(m1_bgrant),
        .ack(m1_ack),
        .msplit(m1_split)
    );

    //--------------------------------------------------------------------------
    // Master Port 2
    //--------------------------------------------------------------------------
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master2 (
        .clk(clk),
        .rstn(rstn),
        .dwdata(d2_wdata),
        .drdata(d2_rdata),
        .daddr(d2_addr),
        .dvalid(d2_valid),
        .dready(d2_ready),
        .dmode(d2_mode),
        .mrdata(m2_rdata),
        .mwdata(m2_wdata),
        .mmode(m2_mode),
        .mvalid(m2_mvalid),
        .svalid(m2_svalid),
        .mbreq(m2_breq),
        .mbgrant(m2_bgrant),
        .ack(m2_ack),
        .msplit(m2_split)
    );

    //--------------------------------------------------------------------------
    // Slave 1 (2KB, No Split)
    //--------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------
    // Slave 2 (4KB, No Split)
    //--------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------
    // Slave 3 (4KB, Split Enabled)
    //--------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------
    // Bus Interconnect
    //--------------------------------------------------------------------------
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) bus (
        .clk(clk),
        .rstn(rstn),
        
        // Master 1 connections
        .m1_rdata(m1_rdata),
        .m1_wdata(m1_wdata),
        .m1_mode(m1_mode),
        .m1_mvalid(m1_mvalid),
        .m1_svalid(m1_svalid),
        .m1_breq(m1_breq),
        .m1_bgrant(m1_bgrant),
        .m1_ack(m1_ack),
        .m1_split(m1_split),
        
        // Master 2 connections
        .m2_rdata(m2_rdata),
        .m2_wdata(m2_wdata),
        .m2_mode(m2_mode),
        .m2_mvalid(m2_mvalid),
        .m2_svalid(m2_svalid),
        .m2_breq(m2_breq),
        .m2_bgrant(m2_bgrant),
        .m2_ack(m2_ack),
        .m2_split(m2_split),
        
        // Slave 1 connections
        .s1_rdata(s1_rdata),
        .s1_wdata(s1_wdata),
        .s1_mode(s1_mode),
        .s1_mvalid(s1_mvalid),
        .s1_svalid(s1_svalid),
        .s1_ready(s1_ready),
        
        // Slave 2 connections
        .s2_rdata(s2_rdata),
        .s2_wdata(s2_wdata),
        .s2_mode(s2_mode),
        .s2_mvalid(s2_mvalid),
        .s2_svalid(s2_svalid),
        .s2_ready(s2_ready),
        
        // Slave 3 connections
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
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================
    
    // Task: Master 2 Write
    task m2_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            $display("\n[TEST @%0t] Master 2 WRITE: addr=0x%h, data=0x%h", $time, addr, data);
            @(posedge clk);
            d2_addr = addr;
            d2_wdata = data;
            d2_mode = 1;  // Write
            d2_valid = 1;
            @(posedge clk);
            d2_valid = 0;
            // Wait for ready to go low (transaction started)
            wait (d2_ready == 0);
            // Wait for ready to go high (transaction complete)
            wait (d2_ready == 1);
            @(posedge clk);
            @(posedge clk);
            $display("[TEST @%0t] Master 2 WRITE complete\n", $time);
        end
    endtask

    // Task: Master 2 Read
    task m2_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        begin
            $display("\n[TEST @%0t] Master 2 READ: addr=0x%h", $time, addr);
            $display("[TEST @%0t] Before read request: d2_rdata=0x%h", $time, d2_rdata);
            @(posedge clk);
            d2_addr = addr;
            d2_mode = 0;  // Read
            d2_valid = 1;
            @(posedge clk);
            d2_valid = 0;
            $display("[TEST @%0t] Read request sent, d2_rdata=0x%h", $time, d2_rdata);
            // BUGFIX: Wait for d2_ready to go LOW (transaction starts), then HIGH (transaction completes)
            wait (d2_ready == 0);
            $display("[TEST @%0t] d2_ready de-asserted (transaction started)", $time);
            wait (d2_ready == 1);
            $display("[TEST @%0t] d2_ready asserted (transaction complete), d2_rdata=0x%h", $time, d2_rdata);
            @(posedge clk);
            $display("[TEST @%0t] After 1 clock, d2_rdata=0x%h", $time, d2_rdata);
            @(posedge clk);
            $display("[TEST @%0t] After 2 clocks, d2_rdata=0x%h", $time, d2_rdata);
            data = d2_rdata;
            $display("[TEST @%0t] Master 2 READ complete: got data=0x%h\n", $time, data);
        end
    endtask

    //==========================================================================
    // Main Test Stimulus
    //==========================================================================
    initial begin
        // Waveform dump
        $dumpfile("simple_read_test.vcd");
        $dumpvars(0, simple_read_test);
        
        // Initialize signals
        rstn = 0;
        d1_valid = 0;
        d1_wdata = 8'b0;
        d1_addr = 16'b0;
        d1_mode = 0;
        d2_valid = 0;
        d2_wdata = 8'b0;
        d2_addr = 16'b0;
        d2_mode = 0;
        
        // Reset sequence
        repeat(3) @(posedge clk);
        rstn = 1;
        $display("\n========== Simple Read Test Started ==========\n");
        repeat(2) @(posedge clk);
        
        //======================================================================
        // Test 1: Write then read back (same address)
        //======================================================================
        $display("========== TEST 1: Write 0xAA to 0x1000, then read back ==========");
        m2_write(16'h1000, 8'hAA);
        m2_read(16'h1000, d2_wdata);  // Reusing d2_wdata as temp variable
        
        test_count = test_count + 1;
        if (d2_rdata == 8'hAA) begin
            $display(">>> TEST 1 PASSED");
        end else begin
            $display(">>> TEST 1 FAILED: Expected 0xAA, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // Test 2: Write different value to different address, read back
        //======================================================================
        $display("\n========== TEST 2: Write 0x55 to 0x1100, then read back ==========");
        m2_write(16'h1100, 8'h55);
        m2_read(16'h1100, d2_wdata);
        
        test_count = test_count + 1;
        if (d2_rdata == 8'h55) begin
            $display(">>> TEST 2 PASSED");
        end else begin
            $display(">>> TEST 2 FAILED: Expected 0x55, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // Test 3: Read from first address again (should still be 0xAA)
        //======================================================================
        $display("\n========== TEST 3: Read from 0x1000 again (should be 0xAA) ==========");
        m2_read(16'h1000, d2_wdata);
        
        test_count = test_count + 1;
        if (d2_rdata == 8'hAA) begin
            $display(">>> TEST 3 PASSED");
        end else begin
            $display(">>> TEST 3 FAILED: Expected 0xAA, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // Test 4: Multiple write-read cycles
        //======================================================================
        $display("\n========== TEST 4: Multiple write-read cycles ==========");
        m2_write(16'h1200, 8'hDE);
        m2_read(16'h1200, d2_wdata);
        test_count = test_count + 1;
        if (d2_rdata == 8'hDE) begin
            $display(">>> TEST 4a PASSED");
        end else begin
            $display(">>> TEST 4a FAILED: Expected 0xDE, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        m2_write(16'h1300, 8'hAD);
        m2_read(16'h1300, d2_wdata);
        test_count = test_count + 1;
        if (d2_rdata == 8'hAD) begin
            $display(">>> TEST 4b PASSED");
        end else begin
            $display(">>> TEST 4b FAILED: Expected 0xAD, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        m2_write(16'h1400, 8'hBE);
        m2_read(16'h1400, d2_wdata);
        test_count = test_count + 1;
        if (d2_rdata == 8'hBE) begin
            $display(">>> TEST 4c PASSED");
        end else begin
            $display(">>> TEST 4c FAILED: Expected 0xBE, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        m2_write(16'h1500, 8'hEF);
        m2_read(16'h1500, d2_wdata);
        test_count = test_count + 1;
        if (d2_rdata == 8'hEF) begin
            $display(">>> TEST 4d PASSED");
        end else begin
            $display(">>> TEST 4d FAILED: Expected 0xEF, got 0x%h", d2_rdata);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // Test Summary
        //======================================================================
        repeat(10) @(posedge clk);
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Total tests: %0d", test_count);
        $display("  Passed: %0d", test_count - error_count);
        $display("  Failed: %0d", error_count);
        if (error_count == 0) begin
            $display("  *** ALL TESTS PASSED ***");
        end else begin
            $display("  *** SOME TESTS FAILED ***");
        end
        $display("========================================\n");
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #500000;  // 500us timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
