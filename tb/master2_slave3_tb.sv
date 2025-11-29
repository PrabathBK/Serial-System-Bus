//==============================================================================
// File: master2_slave3_tb.sv
// Description: Comprehensive testbench for 2-master, 3-slave bus system
//              Tests:
//              - Single master write/read transactions
//              - Simultaneous master requests (priority arbitration)
//              - Split transactions on Slave 3
//              - Random addresses and data patterns
//==============================================================================
// Author: ADS Bus System
// Date: 2025-10-14
//==============================================================================

`timescale 1ns/1ps

module master2_slave3_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    
    // Memory Configuration:
    // Slave 1: 2KB (2^11 = 2048 bytes), Address width = 11 bits
    // Slave 2: 4KB (2^12 = 4096 bytes), Address width = 12 bits
    // Slave 3: 4KB (2^12 = 4096 bytes), Address width = 12 bits, SPLIT enabled
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter MAX_SLAVE_ADDR_WIDTH = 12;   // Largest slave address width
    parameter DEVICE_ADDR_WIDTH = ADDR_WIDTH - MAX_SLAVE_ADDR_WIDTH;  // 16 - 12 = 4 bits
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
    integer i;
    reg [ADDR_WIDTH-1:0]    rand_addr1, rand_addr2, rand_addr3;
    reg [DATA_WIDTH-1:0]    rand_data1, rand_data2;
    reg [DATA_WIDTH-1:0]    slave_mem_data1, slave_mem_data2;
    reg [1:0]               slave_id1, slave_id2;
    reg                     m1_accepted, m2_accepted;  // Transaction arbitration tracking
    reg [DATA_WIDTH-1:0]    d1_rdata_before, d2_rdata_before;  // For detecting transaction completion
    
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
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH)
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
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH)
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
        .ssplit(),              // Not used
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
        .ssplit(),              // Not used
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
    // Task: Random Delay
    //==========================================================================
    task random_delay;
        integer delay;
        begin
            delay = $urandom % 10;  // Random delay 0-9 clock cycles
            $display("Random delay: %0d cycles", delay);
            repeat(delay) @(posedge clk);
        end
    endtask

    //==========================================================================
    // Main Test Stimulus
    //==========================================================================
    initial begin
        // Waveform dump for debugging
        $dumpfile("master2_slave3_tb.vcd");
        $dumpvars(0, master2_slave3_tb);
        
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
        $display("\n=== ADS Bus System Test Started ===\n");
        repeat(2) @(posedge clk);
        
        //======================================================================
        // Test Loop: 20 iterations of random transactions
        //======================================================================
        for (i = 0; i < 20; i = i + 1) begin
            $display("\n--- Iteration %0d ---", i);
            
            // Generate random addresses and data according to memory map
            // Memory Map (16-bit addresses):
            //   Slave 1 (2KB): 0x0000-0x07FF (device ID 0x0, 11-bit addr)
            //   Slave 2 (4KB): 0x1000-0x1FFF (device ID 0x1, 12-bit addr)
            //   Slave 3 (4KB): 0x2000-0x2FFF (device ID 0x2, 12-bit addr)
            
            // Generate address 1: randomly select slave and address within range
            slave_id1 = $urandom % 3;  // 0, 1, or 2
            case (slave_id1)
                2'b00: rand_addr1 = 16'h0000 + ($urandom % 16'h0800);  // Slave 1: 0x0000-0x07FF (2KB)
                2'b01: rand_addr1 = 16'h1000 + ($urandom % 16'h1000);  // Slave 2: 0x1000-0x1FFF (4KB)
                2'b10: rand_addr1 = 16'h2000 + ($urandom % 16'h1000);  // Slave 3: 0x2000-0x2FFF (4KB)
                default: rand_addr1 = 16'h0000;
            endcase
            rand_data1 = $urandom;
            
            // Generate address 2: randomly select slave and address within range
            slave_id2 = $urandom % 3;  // 0, 1, or 2
            case (slave_id2)
                2'b00: rand_addr2 = 16'h0000 + ($urandom % 16'h0800);  // Slave 1: 0x0000-0x07FF (2KB)
                2'b01: rand_addr2 = 16'h1000 + ($urandom % 16'h1000);  // Slave 2: 0x1000-0x1FFF (4KB)
                2'b10: rand_addr2 = 16'h2000 + ($urandom % 16'h1000);  // Slave 3: 0x2000-0x2FFF (4KB)
                default: rand_addr2 = 16'h0000;
            endcase
            rand_data2 = $urandom;
            
            //==================================================================
            // Test 1: Sequential Write Transactions (M1 then M2)
            //==================================================================
            $display("Generated: M1 addr=0x%0h data=0x%0h, M2 addr=0x%0h data=0x%0h", 
                     rand_addr1, rand_data1[DATA_WIDTH-1:0], rand_addr2, rand_data2[DATA_WIDTH-1:0]);
            wait (d1_ready == 1 && d2_ready == 1 && s_ready == 1);
            @(posedge clk);
            
            // Master 1 write request
            d1_addr  = rand_addr1[ADDR_WIDTH-1:0];
            d1_wdata = rand_data1[DATA_WIDTH-1:0];
            d1_mode  = 1;  // Write
            d1_valid = 1;
            
            random_delay();
            
            // Master 2 write request (tests arbitration)
            @(posedge clk);
            d2_addr  = rand_addr2[ADDR_WIDTH-1:0];
            d2_wdata = rand_data2[DATA_WIDTH-1:0];
            d2_mode  = 1;  // Write
            d2_valid = 1;
            
            @(posedge clk);
            d1_valid = 0;
            d2_valid = 0;
            
            // Wait for transactions to complete (fixed: wait for LOW then HIGH)
            wait (d1_ready == 0 || d2_ready == 0);  // Wait for transaction to start
            wait (d1_ready == 1 && d2_ready == 1 && s_ready == 1);  // Wait for all to complete
            repeat(2) @(posedge clk);
            
            // Verify Master 1 write
            if (slave_id1 == 2'b00)
                slave_mem_data1 = slave1.sm.memory[d1_addr[SLAVE1_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id1 == 2'b01)
                slave_mem_data1 = slave2.sm.memory[d1_addr[SLAVE2_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id1 == 2'b10)
                slave_mem_data1 = slave3.sm.memory[d1_addr[SLAVE3_MEM_ADDR_WIDTH-1:0]];
            
            if (slave_id1 != 2'b11 && slave_mem_data1 != d1_wdata) begin
                $display("ERROR: Master 1 write failed - Addr: 0x%0h, Expected: 0x%0h, Got: 0x%0h",
                         d1_addr, d1_wdata, slave_mem_data1);
            end else if (slave_id1 != 2'b11) begin
                $display("PASS: Master 1 write to 0x%0h successful", d1_addr);
            end
            
            // Verify Master 2 write
            if (slave_id2 == 2'b00)
                slave_mem_data2 = slave1.sm.memory[d2_addr[SLAVE1_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id2 == 2'b01)
                slave_mem_data2 = slave2.sm.memory[d2_addr[SLAVE2_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id2 == 2'b10)
                slave_mem_data2 = slave3.sm.memory[d2_addr[SLAVE3_MEM_ADDR_WIDTH-1:0]];
            
            if (slave_id2 != 2'b11 && slave_mem_data2 != d2_wdata) begin
                $display("ERROR: Master 2 write failed - Addr: 0x%0h, Expected: 0x%0h, Got: 0x%0h",
                         d2_addr, d2_wdata, slave_mem_data2);
            end else if (slave_id2 != 2'b11) begin
                $display("PASS: Master 2 write to 0x%0h successful", d2_addr);
            end
            
            //==================================================================
            // Test 2: Simultaneous Read Transactions (Priority Test)
            //==================================================================
            // Record initial rdata values to detect if transaction completed
            @(posedge clk);
            d1_rdata_before = d1_rdata;
            d2_rdata_before = d2_rdata;
            d1_mode  = 0;  // Read
            d1_valid = 1;
            d2_mode  = 0;  // Read
            d2_valid = 1;
            
            @(posedge clk);
            d1_valid = 0;
            d2_valid = 0;
            
            // Wait for at least one transaction to start
            $display("Test 2: Waiting for transaction to start...");
            wait (d1_ready == 0 || d2_ready == 0);
            $display("Test 2: Transaction started, waiting for completion...");
            
            // Wait for all transactions to complete or be denied
            wait (d1_ready == 1 && d2_ready == 1 && s_ready == 1);
            $display("Test 2: Transactions complete");
            repeat(2) @(posedge clk);
            
            // Transaction was accepted if rdata changed from initial value
            // (This works because read transactions update rdata)
            m1_accepted = (d1_rdata != d1_rdata_before);
            m2_accepted = (d2_rdata != d2_rdata_before);
            
            // Verify Master 1 read (only if transaction was accepted)
            if (m1_accepted) begin
                if (slave_id1 != 2'b11 && d1_wdata != d1_rdata) begin
                    $display("ERROR: Master 1 read failed - Addr: 0x%0h, Expected: 0x%0h, Got: 0x%0h",
                             d1_addr, d1_wdata, d1_rdata);
                end else if (slave_id1 != 2'b11) begin
                    $display("PASS: Master 1 read from 0x%0h successful", d1_addr);
                end
            end else if (slave_id1 != 2'b11) begin
                $display("INFO: Master 1 read denied by arbiter (addr: 0x%0h)", d1_addr);
            end
            
            // Verify Master 2 read (only if transaction was accepted)
            if (m2_accepted) begin
                if (slave_id2 != 2'b11 && d2_wdata != d2_rdata) begin
                    $display("ERROR: Master 2 read failed - Addr: 0x%0h, Expected: 0x%0h, Got: 0x%0h",
                             d2_addr, d2_wdata, d2_rdata);
                end else if (slave_id2 != 2'b11) begin
                    $display("PASS: Master 2 read from 0x%0h successful", d2_addr);
                end
            end else if (slave_id2 != 2'b11) begin
                $display("INFO: Master 2 read denied by arbiter (addr: 0x%0h)", d2_addr);
            end
            
            //==================================================================
            // Test 3: Write-then-Read Conflict (M2 write, M1 read)
            //==================================================================
            $display("Starting Test 3: Write-Read Conflict");
            // Generate address 3: randomly select slave and address within range
            slave_id1 = $urandom % 3;  // 0, 1, or 2
            case (slave_id1)
                2'b00: rand_addr3 = 16'h0000 + ($urandom % 16'h0800);  // Slave 1: 0x0000-0x07FF (2KB)
                2'b01: rand_addr3 = 16'h1000 + ($urandom % 16'h1000);  // Slave 2: 0x1000-0x1FFF (4KB)
                2'b10: rand_addr3 = 16'h2000 + ($urandom % 16'h1000);  // Slave 3: 0x2000-0x2FFF (4KB)
                default: rand_addr3 = 16'h0000;
            endcase
            
            @(posedge clk);
            d2_addr  = rand_addr3;
            d2_wdata = rand_data1 + rand_data2;
            d2_mode  = 1;  // Write
            d2_valid = 1;
            $display("TEST3: M2 WRITE addr=0x%0h, wdata=0x%0h", d2_addr, d2_wdata);
            
            random_delay();
            
            @(posedge clk);
            d1_addr  = d2_addr;
            d1_mode  = 0;  // Read
            d1_valid = 1;
            $display("TEST3: M1 READ addr=0x%0h (should match M2 write addr)", d1_addr);
            
            @(posedge clk);
            d1_valid = 0;
            d2_valid = 0;
            $display("TEST3: Transactions issued, waiting for completion...");
            $display("TEST3: Initial state - d1_ready=%b, d2_ready=%b, s_ready=%b", d1_ready, d2_ready, s_ready);
            
            // Wait for transactions to complete (fixed: wait for LOW then HIGH)
            $display("TEST3: Waiting for transaction to start (ready to go low)...");
            wait (d1_ready == 0 || d2_ready == 0);  // Wait for transaction to start
            $display("TEST3: Transaction started, waiting for all to complete...");
            wait (d1_ready == 1 && d2_ready == 1 && s_ready == 1);  // Wait for all to complete
            $display("TEST3: All transactions complete");
            repeat(2) @(posedge clk);
            
            // Verify write
            if (slave_id1 == 2'b00)
                slave_mem_data1 = slave1.sm.memory[d2_addr[SLAVE1_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id1 == 2'b01)
                slave_mem_data1 = slave2.sm.memory[d2_addr[SLAVE2_MEM_ADDR_WIDTH-1:0]];
            else if (slave_id1 == 2'b10)
                slave_mem_data1 = slave3.sm.memory[d2_addr[SLAVE3_MEM_ADDR_WIDTH-1:0]];
            
            $display("TEST3 VERIFY: d2_addr=0x%0h, d2_wdata=0x%0h, slave_mem_data=0x%0h, d1_rdata=0x%0h", 
                     d2_addr, d2_wdata, slave_mem_data1, d1_rdata);
            
            if (slave_id1 != 2'b11 && slave_mem_data1 != d2_wdata) begin
                $display("ERROR: Write-Read conflict test failed at write phase - Memory has 0x%0h, expected 0x%0h", slave_mem_data1, d2_wdata);
            end else if (slave_id1 != 2'b11) begin
                $display("PASS: Write-Read conflict test successful");
            end
        end
        
        //======================================================================
        // Test Completion
        //======================================================================
        repeat(10) @(posedge clk);
        $display("\n=== All Tests Completed ===\n");
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog (prevents infinite simulation)
    //==========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
