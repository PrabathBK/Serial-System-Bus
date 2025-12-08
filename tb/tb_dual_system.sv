//==============================================================================
// File: tb_dual_system.sv
// Description: Dual-system testbench for inter-FPGA communication via UART bridge
//              
//              Tests two interconnected bus systems (System A and System B) with:
//              - Internal writes (within same system)
//              - External writes (cross-system via UART bridge)
//
// System Architecture (identical for A and B):
//   - Master 1 (M1): Local master for initiating transactions
//   - Master 2 (M2): Bus Bridge Master - receives UART commands from other system
//   - Slave 1 (S1):  Local memory (2KB)
//   - Slave 2 (S2):  Local memory (4KB)
//   - Slave 3 (S3):  Bus Bridge Slave - forwards commands via UART to other system
//
// UART Cross-Connections:
//   System A Bridge Slave TX  --> System B Bridge Master RX (commands A->B)
//   System B Bridge Master TX --> System A Bridge Slave RX  (responses B->A)
//   System B Bridge Slave TX  --> System A Bridge Master RX (commands B->A)
//   System A Bridge Master TX --> System B Bridge Slave RX  (responses A->B)
//
// Test Cases:
//   1. Internal Write: System A M1 writes to System A S1
//   2. Internal Write: System A M1 writes to System A S2
//   3. External Write: System A M1 writes to System B S1 (via bridge)
//   4. External Write: System A M1 writes to System B S2 (via bridge)
//   5. Internal Write: System A M1 writes to System A S3 (local memory)
//   6. Bridge Write:   System A M2 writes to System A S3 (triggered via UART from B)
//   7. External Write: System A M1 writes to System B S3 (via bridge, to B's S3 local memory)
//
// Target Device: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================

`timescale 1ns / 1ps

module tb_dual_system;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 20;              // 50 MHz clock
    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 8;
    localparam SLAVE1_MEM_ADDR_WIDTH = 11;   // 2KB
    localparam SLAVE2_MEM_ADDR_WIDTH = 12;   // 4KB
    localparam SLAVE3_MEM_ADDR_WIDTH = 12;   // 4KB (Bridge)
    localparam BB_ADDR_WIDTH = 12;
    
    // UART: Use faster baud rate for simulation (reduced from 5208 to 52)
    // Real hardware: 50MHz / 9600 = 5208
    // Simulation:    50MHz / 960000 = 52 (100x faster)
    localparam UART_CLOCKS_PER_PULSE = 52;
    
    // Timeout for UART transactions (in clock cycles)
    // At 52 clocks/bit, 21 bits (start + 8 data + parity + stop) * 52 = ~1100 cycles per byte
    // Bridge protocol: addr(12b) + data(8b) + mode(1b) = 21 bits = ~3 bytes = ~3300 cycles
    // With margin: 50000 cycles should be plenty
    localparam UART_TIMEOUT = 100000;
    
    //==========================================================================
    // Testbench Signals
    //==========================================================================
    reg clk;
    reg rstn;
    
    // Test control
    integer test_num;
    integer errors;
    reg [31:0] timeout_counter;
    
    //==========================================================================
    // System A Signals
    //==========================================================================
    // Master 1 device interface (local master)
    reg  [DATA_WIDTH-1:0] a_m1_dwdata;
    wire [DATA_WIDTH-1:0] a_m1_drdata;
    reg  [ADDR_WIDTH-1:0] a_m1_daddr;
    reg                   a_m1_dvalid;
    wire                  a_m1_dready;
    reg                   a_m1_dmode;
    
    // Master 1 bus interface
    wire a_m1_rdata, a_m1_wdata, a_m1_mode, a_m1_mvalid, a_m1_svalid;
    wire a_m1_breq, a_m1_bgrant, a_m1_ack, a_m1_split;
    
    // Master 2 bus interface (bridge master)
    wire a_m2_rdata, a_m2_wdata, a_m2_mode, a_m2_mvalid, a_m2_svalid;
    wire a_m2_breq, a_m2_bgrant, a_m2_ack, a_m2_split;
    
    // Slave interfaces
    wire a_s1_rdata, a_s1_wdata, a_s1_mode, a_s1_mvalid, a_s1_svalid, a_s1_ready;
    wire a_s2_rdata, a_s2_wdata, a_s2_mode, a_s2_mvalid, a_s2_svalid, a_s2_ready;
    wire a_s3_rdata, a_s3_wdata, a_s3_mode, a_s3_mvalid, a_s3_svalid, a_s3_ready;
    wire a_s3_split;
    wire a_split_grant;
    
    // UART lines
    wire a_bridge_m_tx, a_bridge_m_rx;
    wire a_bridge_s_tx, a_bridge_s_rx;
    
    //==========================================================================
    // System B Signals
    //==========================================================================
    // Master 1 device interface (local master)
    reg  [DATA_WIDTH-1:0] b_m1_dwdata;
    wire [DATA_WIDTH-1:0] b_m1_drdata;
    reg  [ADDR_WIDTH-1:0] b_m1_daddr;
    reg                   b_m1_dvalid;
    wire                  b_m1_dready;
    reg                   b_m1_dmode;
    
    // Master 1 bus interface
    wire b_m1_rdata, b_m1_wdata, b_m1_mode, b_m1_mvalid, b_m1_svalid;
    wire b_m1_breq, b_m1_bgrant, b_m1_ack, b_m1_split;
    
    // Master 2 bus interface (bridge master)
    wire b_m2_rdata, b_m2_wdata, b_m2_mode, b_m2_mvalid, b_m2_svalid;
    wire b_m2_breq, b_m2_bgrant, b_m2_ack, b_m2_split;
    
    // Slave interfaces
    wire b_s1_rdata, b_s1_wdata, b_s1_mode, b_s1_mvalid, b_s1_svalid, b_s1_ready;
    wire b_s2_rdata, b_s2_wdata, b_s2_mode, b_s2_mvalid, b_s2_svalid, b_s2_ready;
    wire b_s3_rdata, b_s3_wdata, b_s3_mode, b_s3_mvalid, b_s3_svalid, b_s3_ready;
    wire b_s3_split;
    wire b_split_grant;
    
    // UART lines
    wire b_bridge_m_tx, b_bridge_m_rx;
    wire b_bridge_s_tx, b_bridge_s_rx;
    
    //==========================================================================
    // UART Cross-Connections
    //==========================================================================
    // System A Bridge Slave TX --> System B Bridge Master RX (A sends commands to B)
    assign b_bridge_m_rx = a_bridge_s_tx;
    
    // System B Bridge Master TX --> System A Bridge Slave RX (B sends responses to A)
    assign a_bridge_s_rx = b_bridge_m_tx;
    
    // System B Bridge Slave TX --> System A Bridge Master RX (B sends commands to A)
    assign a_bridge_m_rx = b_bridge_s_tx;
    
    // System A Bridge Master TX --> System B Bridge Slave RX (A sends responses to B)
    assign b_bridge_s_rx = a_bridge_m_tx;
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // System A Instantiation
    //==========================================================================
    
    // Master Port 1 - Local master for System A
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) a_master1_port (
        .clk(clk),
        .rstn(rstn),
        .dwdata(a_m1_dwdata),
        .drdata(a_m1_drdata),
        .daddr(a_m1_daddr),
        .dvalid(a_m1_dvalid),
        .dready(a_m1_dready),
        .dmode(a_m1_dmode),
        .mrdata(a_m1_rdata),
        .mwdata(a_m1_wdata),
        .mmode(a_m1_mode),
        .mvalid(a_m1_mvalid),
        .svalid(a_m1_svalid),
        .mbreq(a_m1_breq),
        .mbgrant(a_m1_bgrant),
        .msplit(a_m1_split),
        .ack(a_m1_ack)
    );
    
    // Master 2 - Bus Bridge Master for System A
    bus_bridge_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) a_master2_bridge (
        .clk(clk),
        .rstn(rstn),
        .mrdata(a_m2_rdata),
        .mwdata(a_m2_wdata),
        .mmode(a_m2_mode),
        .mvalid(a_m2_mvalid),
        .svalid(a_m2_svalid),
        .mbreq(a_m2_breq),
        .mbgrant(a_m2_bgrant),
        .msplit(a_m2_split),
        .ack(a_m2_ack),
        .lmem_wen(1'b0),
        .lmem_ren(1'b0),
        .lmem_addr(11'b0),
        .lmem_wdata(8'b0),
        .lmem_rdata(),
        .lmem_rvalid(),
        .u_tx(a_bridge_m_tx),
        .u_rx(a_bridge_m_rx)
    );
    
    // Bus Interconnect for System A
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) a_bus_inst (
        .clk(clk),
        .rstn(rstn),
        // Master 1
        .m1_rdata(a_m1_rdata),
        .m1_wdata(a_m1_wdata),
        .m1_mode(a_m1_mode),
        .m1_mvalid(a_m1_mvalid),
        .m1_svalid(a_m1_svalid),
        .m1_breq(a_m1_breq),
        .m1_bgrant(a_m1_bgrant),
        .m1_ack(a_m1_ack),
        .m1_split(a_m1_split),
        // Master 2
        .m2_rdata(a_m2_rdata),
        .m2_wdata(a_m2_wdata),
        .m2_mode(a_m2_mode),
        .m2_mvalid(a_m2_mvalid),
        .m2_svalid(a_m2_svalid),
        .m2_breq(a_m2_breq),
        .m2_bgrant(a_m2_bgrant),
        .m2_ack(a_m2_ack),
        .m2_split(a_m2_split),
        // Slave 1
        .s1_rdata(a_s1_rdata),
        .s1_wdata(a_s1_wdata),
        .s1_mode(a_s1_mode),
        .s1_mvalid(a_s1_mvalid),
        .s1_svalid(a_s1_svalid),
        .s1_ready(a_s1_ready),
        // Slave 2
        .s2_rdata(a_s2_rdata),
        .s2_wdata(a_s2_wdata),
        .s2_mode(a_s2_mode),
        .s2_mvalid(a_s2_mvalid),
        .s2_svalid(a_s2_svalid),
        .s2_ready(a_s2_ready),
        // Slave 3
        .s3_rdata(a_s3_rdata),
        .s3_wdata(a_s3_wdata),
        .s3_mode(a_s3_mode),
        .s3_mvalid(a_s3_mvalid),
        .s3_svalid(a_s3_svalid),
        .s3_ready(a_s3_ready),
        .s3_split(a_s3_split),
        .split_grant(a_split_grant)
    );
    
    // Slave 1 - Local Memory (2KB) for System A
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(2048)
    ) a_slave1_inst (
        .clk(clk),
        .rstn(rstn),
        .srdata(a_s1_rdata),
        .swdata(a_s1_wdata),
        .smode(a_s1_mode),
        .svalid(a_s1_svalid),
        .mvalid(a_s1_mvalid),
        .sready(a_s1_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    // Slave 2 - Local Memory (4KB) for System A
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(4096)
    ) a_slave2_inst (
        .clk(clk),
        .rstn(rstn),
        .srdata(a_s2_rdata),
        .swdata(a_s2_wdata),
        .smode(a_s2_mode),
        .svalid(a_s2_svalid),
        .mvalid(a_s2_mvalid),
        .sready(a_s2_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    // Slave 3 - Bus Bridge Slave for System A
    bus_bridge_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) a_slave3_bridge (
        .clk(clk),
        .rstn(rstn),
        .swdata(a_s3_wdata),
        .smode(a_s3_mode),
        .mvalid(a_s3_mvalid),
        .split_grant(a_split_grant),
        .srdata(a_s3_rdata),
        .svalid(a_s3_svalid),
        .sready(a_s3_ready),
        .ssplit(a_s3_split),
        .u_tx(a_bridge_s_tx),
        .u_rx(a_bridge_s_rx)
    );
    
    //==========================================================================
    // System B Instantiation
    //==========================================================================
    
    // Master Port 1 - Local master for System B
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) b_master1_port (
        .clk(clk),
        .rstn(rstn),
        .dwdata(b_m1_dwdata),
        .drdata(b_m1_drdata),
        .daddr(b_m1_daddr),
        .dvalid(b_m1_dvalid),
        .dready(b_m1_dready),
        .dmode(b_m1_dmode),
        .mrdata(b_m1_rdata),
        .mwdata(b_m1_wdata),
        .mmode(b_m1_mode),
        .mvalid(b_m1_mvalid),
        .svalid(b_m1_svalid),
        .mbreq(b_m1_breq),
        .mbgrant(b_m1_bgrant),
        .msplit(b_m1_split),
        .ack(b_m1_ack)
    );
    
    // Master 2 - Bus Bridge Master for System B
    bus_bridge_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) b_master2_bridge (
        .clk(clk),
        .rstn(rstn),
        .mrdata(b_m2_rdata),
        .mwdata(b_m2_wdata),
        .mmode(b_m2_mode),
        .mvalid(b_m2_mvalid),
        .svalid(b_m2_svalid),
        .mbreq(b_m2_breq),
        .mbgrant(b_m2_bgrant),
        .msplit(b_m2_split),
        .ack(b_m2_ack),
        .lmem_wen(1'b0),
        .lmem_ren(1'b0),
        .lmem_addr(11'b0),
        .lmem_wdata(8'b0),
        .lmem_rdata(),
        .lmem_rvalid(),
        .u_tx(b_bridge_m_tx),
        .u_rx(b_bridge_m_rx)
    );
    
    // Bus Interconnect for System B
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) b_bus_inst (
        .clk(clk),
        .rstn(rstn),
        // Master 1
        .m1_rdata(b_m1_rdata),
        .m1_wdata(b_m1_wdata),
        .m1_mode(b_m1_mode),
        .m1_mvalid(b_m1_mvalid),
        .m1_svalid(b_m1_svalid),
        .m1_breq(b_m1_breq),
        .m1_bgrant(b_m1_bgrant),
        .m1_ack(b_m1_ack),
        .m1_split(b_m1_split),
        // Master 2
        .m2_rdata(b_m2_rdata),
        .m2_wdata(b_m2_wdata),
        .m2_mode(b_m2_mode),
        .m2_mvalid(b_m2_mvalid),
        .m2_svalid(b_m2_svalid),
        .m2_breq(b_m2_breq),
        .m2_bgrant(b_m2_bgrant),
        .m2_ack(b_m2_ack),
        .m2_split(b_m2_split),
        // Slave 1
        .s1_rdata(b_s1_rdata),
        .s1_wdata(b_s1_wdata),
        .s1_mode(b_s1_mode),
        .s1_mvalid(b_s1_mvalid),
        .s1_svalid(b_s1_svalid),
        .s1_ready(b_s1_ready),
        // Slave 2
        .s2_rdata(b_s2_rdata),
        .s2_wdata(b_s2_wdata),
        .s2_mode(b_s2_mode),
        .s2_mvalid(b_s2_mvalid),
        .s2_svalid(b_s2_svalid),
        .s2_ready(b_s2_ready),
        // Slave 3
        .s3_rdata(b_s3_rdata),
        .s3_wdata(b_s3_wdata),
        .s3_mode(b_s3_mode),
        .s3_mvalid(b_s3_mvalid),
        .s3_svalid(b_s3_svalid),
        .s3_ready(b_s3_ready),
        .s3_split(b_s3_split),
        .split_grant(b_split_grant)
    );
    
    // Slave 1 - Local Memory (2KB) for System B
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(2048)
    ) b_slave1_inst (
        .clk(clk),
        .rstn(rstn),
        .srdata(b_s1_rdata),
        .swdata(b_s1_wdata),
        .smode(b_s1_mode),
        .svalid(b_s1_svalid),
        .mvalid(b_s1_mvalid),
        .sready(b_s1_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    // Slave 2 - Local Memory (4KB) for System B
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(4096)
    ) b_slave2_inst (
        .clk(clk),
        .rstn(rstn),
        .srdata(b_s2_rdata),
        .swdata(b_s2_wdata),
        .smode(b_s2_mode),
        .svalid(b_s2_svalid),
        .mvalid(b_s2_mvalid),
        .sready(b_s2_ready),
        .ssplit(),
        .split_grant(1'b0)
    );
    
    // Slave 3 - Bus Bridge Slave for System B
    bus_bridge_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) b_slave3_bridge (
        .clk(clk),
        .rstn(rstn),
        .swdata(b_s3_wdata),
        .smode(b_s3_mode),
        .mvalid(b_s3_mvalid),
        .split_grant(b_split_grant),
        .srdata(b_s3_rdata),
        .svalid(b_s3_svalid),
        .sready(b_s3_ready),
        .ssplit(b_s3_split),
        .u_tx(b_bridge_s_tx),
        .u_rx(b_bridge_s_rx)
    );
    
    //==========================================================================
    // Task: Wait for System A M1 Ready with Timeout
    //==========================================================================
    task wait_a_m1_ready;
        input [31:0] max_cycles;
        begin
            timeout_counter = 0;
            while (!a_m1_dready && timeout_counter < max_cycles) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
            end
            if (timeout_counter >= max_cycles) begin
                $display("ERROR: Timeout waiting for System A M1 ready after %0d cycles", max_cycles);
                errors = errors + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Task: System A M1 Write Transaction
    //==========================================================================
    task a_m1_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [31:0] timeout;
        begin
            // Wait for master ready
            wait_a_m1_ready(100);
            
            // Initiate write
            @(posedge clk);
            a_m1_daddr  = addr;
            a_m1_dwdata = data;
            a_m1_dmode  = 1'b1;  // Write mode
            a_m1_dvalid = 1'b1;
            
            @(posedge clk);
            a_m1_dvalid = 1'b0;
            
            // Wait for completion
            wait_a_m1_ready(timeout);
        end
    endtask
    
    //==========================================================================
    // Task: System A M1 Read Transaction
    //==========================================================================
    task a_m1_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        input  [31:0] timeout;
        begin
            // Wait for master ready
            wait_a_m1_ready(100);
            
            // Initiate read
            @(posedge clk);
            a_m1_daddr  = addr;
            a_m1_dwdata = 8'h00;
            a_m1_dmode  = 1'b0;  // Read mode
            a_m1_dvalid = 1'b1;
            
            @(posedge clk);
            a_m1_dvalid = 1'b0;
            
            // Wait for completion
            wait_a_m1_ready(timeout);
            
            // Capture read data
            data = a_m1_drdata;
        end
    endtask
    
    //==========================================================================
    // Task: Wait for System B M1 Ready with Timeout
    //==========================================================================
    task wait_b_m1_ready;
        input [31:0] max_cycles;
        begin
            timeout_counter = 0;
            while (!b_m1_dready && timeout_counter < max_cycles) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
            end
            if (timeout_counter >= max_cycles) begin
                $display("ERROR: Timeout waiting for System B M1 ready after %0d cycles", max_cycles);
                errors = errors + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Task: System B M1 Write Transaction
    //==========================================================================
    task b_m1_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [31:0] timeout;
        begin
            // Wait for master ready
            wait_b_m1_ready(100);
            
            // Initiate write
            @(posedge clk);
            b_m1_daddr  = addr;
            b_m1_dwdata = data;
            b_m1_dmode  = 1'b1;  // Write mode
            b_m1_dvalid = 1'b1;
            
            @(posedge clk);
            b_m1_dvalid = 1'b0;
            
            // Wait for completion
            wait_b_m1_ready(timeout);
        end
    endtask
    
    //==========================================================================
    // VCD Dump
    //==========================================================================
    initial begin
        $dumpfile("tb_dual_system.vcd");
        $dumpvars(0, tb_dual_system);
    end
    
    //==========================================================================
    // Global Timeout
    //==========================================================================
    initial begin
        #50000000;  // 50ms timeout (increased for 7 tests with UART)
        $display("TIMEOUT: Global simulation timeout reached!");
        $finish;
    end
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("=============================================================");
        $display("  Dual-System UART Bridge Testbench");
        $display("  Testing inter-FPGA communication via UART bridge");
        $display("=============================================================");
        
        // Initialize
        errors = 0;
        test_num = 0;
        rstn = 0;
        
        // System A M1 initialization
        a_m1_dwdata = 8'h00;
        a_m1_daddr  = 16'h0000;
        a_m1_dvalid = 1'b0;
        a_m1_dmode  = 1'b0;
        
        // System B M1 initialization (not used in these tests)
        b_m1_dwdata = 8'h00;
        b_m1_daddr  = 16'h0000;
        b_m1_dvalid = 1'b0;
        b_m1_dmode  = 1'b0;
        
        // Reset sequence
        repeat (10) @(posedge clk);
        rstn = 1;
        repeat (10) @(posedge clk);
        
        $display("\n[%0t] Reset complete, starting tests...\n", $time);
        
        //======================================================================
        // Test 1: Internal Write - System A M1 writes to System A S1
        //======================================================================
        test_num = 1;
        $display("-------------------------------------------------------------");
        $display("Test %0d: Internal Write - System A M1 -> System A S1", test_num);
        $display("-------------------------------------------------------------");
        
        // Address format: {device_addr[3:0], mem_addr[11:0]}
        // Slave 1 = device 0x0
        a_m1_write(16'h0010, 8'hA1, 1000);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - Internal write to S1 completed", test_num);
        end else begin
            $display("ERROR: Test %0d - Internal write to S1 failed", test_num);
            errors = errors + 1;
        end
        
        repeat (20) @(posedge clk);
        
        //======================================================================
        // Test 2: Internal Write - System A M1 writes to System A S2
        //======================================================================
        test_num = 2;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: Internal Write - System A M1 -> System A S2", test_num);
        $display("-------------------------------------------------------------");
        
        // Slave 2 = device 0x1
        a_m1_write(16'h1020, 8'hB2, 1000);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - Internal write to S2 completed", test_num);
        end else begin
            $display("ERROR: Test %0d - Internal write to S2 failed", test_num);
            errors = errors + 1;
        end
        
        repeat (20) @(posedge clk);
        
        //======================================================================
        // Test 3: External Write - System A M1 writes to System B S1 via bridge
        //======================================================================
        test_num = 3;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: External Write - System A M1 -> System B S1 (via bridge)", test_num);
        $display("-------------------------------------------------------------");
        
        // Address to Slave 3 (Bridge): device 0x2
        // Bridge forwards to remote Slave 1: addr[11] = 0 means S1
        // Full address: {4'b0010, 12'h030} = 16'h2030
        a_m1_write(16'h2030, 8'hC3, UART_TIMEOUT);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - External write to B:S1 via bridge completed", test_num);
        end else begin
            $display("ERROR: Test %0d - External write to B:S1 via bridge failed (timeout)", test_num);
            errors = errors + 1;
        end
        
        // Extra wait for UART to settle
        repeat (1000) @(posedge clk);
        
        //======================================================================
        // Test 4: External Write - System A M1 writes to System B S2 via bridge
        //======================================================================
        test_num = 4;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: External Write - System A M1 -> System B S2 (via bridge)", test_num);
        $display("-------------------------------------------------------------");
        
        // Bridge forwards to remote Slave 2: addr[11] = 1 means S2
        // Full address: {4'b0010, 1'b1, 11'h040} = 16'h2840
        a_m1_write(16'h2840, 8'hD4, UART_TIMEOUT);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - External write to B:S2 via bridge completed", test_num);
        end else begin
            $display("ERROR: Test %0d - External write to B:S2 via bridge failed (timeout)", test_num);
            errors = errors + 1;
        end
        
        // Extra wait for UART to settle
        repeat (1000) @(posedge clk);
        
        //======================================================================
        // Test 5: Internal Write - System A M1 writes to System A S3 (local memory)
        //======================================================================
        test_num = 5;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: Internal Write - System A M1 -> System A S3 (local memory)", test_num);
        $display("-------------------------------------------------------------");
        
        // Address to Slave 3 (Bridge): device 0x2
        // S3 local memory: addr[11] = 0 (MSB=0 means local, not forwarded via UART)
        // Full address: {4'b0010, 12'h050} = 16'h2050
        a_m1_write(16'h2050, 8'hE5, 1000);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - Internal write to A:S3 local memory completed", test_num);
        end else begin
            $display("ERROR: Test %0d - Internal write to A:S3 local memory failed", test_num);
            errors = errors + 1;
        end
        
        repeat (20) @(posedge clk);
        
        //======================================================================
        // Test 6: Bridge Write - System A M2 writes to System A S3
        //         Triggered by System B M1 writing to B:S3 which forwards via UART to A:M2
        //======================================================================
        test_num = 6;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: Bridge Write - System A M2 -> System A S3 (via UART from B)", test_num);
        $display("-------------------------------------------------------------");
        
        // System B M1 writes to B:S3 with bridge address (MSB=1)
        // B:S3 forwards via UART to A:M2, which then writes to A:S3
        // B:S3 address: device 0x2, addr[11]=1 (bridge mode), target addr = 0x060
        // The bridge master (A:M2) will write to device specified in UART packet
        // UART packet format: {mode, data, addr[11:0]} where addr[11:0] = {device[1:0], mem_addr[9:0]}
        // To target A:S3 (device 2): addr = {2'b10, 10'h060} = 12'h860
        // Full B:S3 address: {4'b0010, 12'h860} = 16'h2860
        b_m1_write(16'h2860, 8'hF6, UART_TIMEOUT);
        
        if (b_m1_dready) begin
            $display("PASS: Test %0d - Bridge write A:M2 -> A:S3 completed", test_num);
        end else begin
            $display("ERROR: Test %0d - Bridge write A:M2 -> A:S3 failed (timeout)", test_num);
            errors = errors + 1;
        end
        
        // Extra wait for UART transaction to complete on System A side
        repeat (UART_TIMEOUT) @(posedge clk);
        
        //======================================================================
        // Test 7: External Write - System A M1 writes to System B S3 (local memory)
        //======================================================================
        test_num = 7;
        $display("\n-------------------------------------------------------------");
        $display("Test %0d: External Write - System A M1 -> System B S3 (via bridge)", test_num);
        $display("-------------------------------------------------------------");
        
        // A:M1 writes to A:S3 with bridge address (MSB=1), targeting B:S3 local memory
        // A:S3 forwards via UART to B:M2, which writes to B:S3 local memory
        // Target: B:S3 (device 2), local memory addr = 0x070
        // UART packet addr: {2'b10, 10'h070} = 12'h870? No wait...
        // B's bridge master receives addr and converts: addr[11:0] becomes {device, mem_addr}
        // To write to B:S3 local memory (not forward again), we need addr[11]=0
        // Target addr: {2'b10, 10'h070} = 12'h270 (device 2, mem_addr 0x070, MSB=0 for local)
        // A:S3 bridge address: {4'b0010, 1'b1, 11'h270} = {4'b0010, 12'hA70} = 16'h2A70
        a_m1_write(16'h2A70, 8'h77, UART_TIMEOUT);
        
        if (a_m1_dready) begin
            $display("PASS: Test %0d - External write to B:S3 via bridge completed", test_num);
        end else begin
            $display("ERROR: Test %0d - External write to B:S3 via bridge failed (timeout)", test_num);
            errors = errors + 1;
        end
        
        // Extra wait for UART to settle
        repeat (UART_TIMEOUT) @(posedge clk);
        
        //======================================================================
        // Test Summary
        //======================================================================
        $display("\n=============================================================");
        $display("  Test Summary");
        $display("=============================================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Errors:      %0d", errors);
        if (errors == 0) begin
            $display("  Result:      ALL PASS");
        end else begin
            $display("  Result:      FAILED");
        end
        $display("=============================================================\n");
        
        repeat (100) @(posedge clk);
        $finish;
    end

endmodule
