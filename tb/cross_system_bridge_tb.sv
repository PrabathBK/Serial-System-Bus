//==============================================================================
// File: cross_system_bridge_tb.sv
// Description: Focused testbench for cross-system bridge communication
//              Tests ONLY the bus bridge (UART) path between two systems
//==============================================================================

`timescale 1ns/1ps

module cross_system_bridge_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB (bus bridge)
    parameter BB_ADDR_WIDTH = 12;
    parameter MAX_SLAVE_ADDR_WIDTH = 12;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    parameter LOCAL_MEM_ADDR_WIDTH = 11;   // 2KB for master local memory
    
    // UART parameters - use faster baud rate for simulation
    parameter UART_CLOCKS_PER_PULSE = 16;  // Fast UART for simulation

    //--------------------------------------------------------------------------
    // Global Signals
    //--------------------------------------------------------------------------
    reg clk;
    reg rstn;

    //==========================================================================
    // System A Signals
    //==========================================================================
    
    // Master 1 Device Interface
    reg  [DATA_WIDTH-1:0]   a_d1_wdata;
    wire [DATA_WIDTH-1:0]   a_d1_rdata;
    reg  [ADDR_WIDTH-1:0]   a_d1_addr;
    reg                     a_d1_valid;
    wire                    a_d1_ready;
    reg                     a_d1_mode;
    
    // Master 1 Local Memory Interface
    reg                     a_m1_lmem_wen;
    reg                     a_m1_lmem_ren;
    reg  [LOCAL_MEM_ADDR_WIDTH-1:0] a_m1_lmem_addr;
    reg  [DATA_WIDTH-1:0]   a_m1_lmem_wdata;
    wire [DATA_WIDTH-1:0]   a_m1_lmem_rdata;
    wire                    a_m1_lmem_rvalid;

    // Bus Signals - System A Master 1
    wire a_m1_rdata, a_m1_wdata, a_m1_mode, a_m1_mvalid, a_m1_svalid;
    wire a_m1_breq, a_m1_bgrant, a_m1_ack, a_m1_split;

    // Master 2 (Bus Bridge Master) Signals
    wire a_m2_rdata, a_m2_wdata, a_m2_mode, a_m2_mvalid, a_m2_svalid;
    wire a_m2_breq, a_m2_bgrant, a_m2_ack, a_m2_split;
    
    // Master 2 Local Memory Interface
    reg                     a_m2_lmem_wen;
    reg                     a_m2_lmem_ren;
    reg  [LOCAL_MEM_ADDR_WIDTH-1:0] a_m2_lmem_addr;
    reg  [DATA_WIDTH-1:0]   a_m2_lmem_wdata;
    wire [DATA_WIDTH-1:0]   a_m2_lmem_rdata;
    wire                    a_m2_lmem_rvalid;

    // Slave Signals
    wire a_s1_rdata, a_s1_wdata, a_s1_mode, a_s1_mvalid, a_s1_svalid, a_s1_ready;
    wire a_s2_rdata, a_s2_wdata, a_s2_mode, a_s2_mvalid, a_s2_svalid, a_s2_ready;
    wire a_s3_rdata, a_s3_wdata, a_s3_mode, a_s3_mvalid, a_s3_svalid, a_s3_ready;
    wire a_s3_split;
    wire a_split_grant;

    // System A UART signals
    wire a_bridge_master_tx, a_bridge_master_rx;
    wire a_bridge_slave_tx, a_bridge_slave_rx;

    //==========================================================================
    // System B Signals
    //==========================================================================
    
    // Master 1 Device Interface
    reg  [DATA_WIDTH-1:0]   b_d1_wdata;
    wire [DATA_WIDTH-1:0]   b_d1_rdata;
    reg  [ADDR_WIDTH-1:0]   b_d1_addr;
    reg                     b_d1_valid;
    wire                    b_d1_ready;
    reg                     b_d1_mode;
    
    // Master 1 Local Memory Interface
    reg                     b_m1_lmem_wen;
    reg                     b_m1_lmem_ren;
    reg  [LOCAL_MEM_ADDR_WIDTH-1:0] b_m1_lmem_addr;
    reg  [DATA_WIDTH-1:0]   b_m1_lmem_wdata;
    wire [DATA_WIDTH-1:0]   b_m1_lmem_rdata;
    wire                    b_m1_lmem_rvalid;

    // Bus Signals - System B Master 1
    wire b_m1_rdata, b_m1_wdata, b_m1_mode, b_m1_mvalid, b_m1_svalid;
    wire b_m1_breq, b_m1_bgrant, b_m1_ack, b_m1_split;

    // Master 2 (Bus Bridge Master) Signals
    wire b_m2_rdata, b_m2_wdata, b_m2_mode, b_m2_mvalid, b_m2_svalid;
    wire b_m2_breq, b_m2_bgrant, b_m2_ack, b_m2_split;
    
    // Master 2 Local Memory Interface
    reg                     b_m2_lmem_wen;
    reg                     b_m2_lmem_ren;
    reg  [LOCAL_MEM_ADDR_WIDTH-1:0] b_m2_lmem_addr;
    reg  [DATA_WIDTH-1:0]   b_m2_lmem_wdata;
    wire [DATA_WIDTH-1:0]   b_m2_lmem_rdata;
    wire                    b_m2_lmem_rvalid;

    // Slave Signals
    wire b_s1_rdata, b_s1_wdata, b_s1_mode, b_s1_mvalid, b_s1_svalid, b_s1_ready;
    wire b_s2_rdata, b_s2_wdata, b_s2_mode, b_s2_mvalid, b_s2_svalid, b_s2_ready;
    wire b_s3_rdata, b_s3_wdata, b_s3_mode, b_s3_mvalid, b_s3_svalid, b_s3_ready;
    wire b_s3_split;
    wire b_split_grant;

    // System B UART signals
    wire b_bridge_master_tx, b_bridge_master_rx;
    wire b_bridge_slave_tx, b_bridge_slave_rx;

    //--------------------------------------------------------------------------
    // UART Cross-Connection
    //--------------------------------------------------------------------------
    // System A Bridge Slave TX -> System B Bridge Master RX
    // System B Bridge Master TX -> System A Bridge Slave RX
    // System B Bridge Slave TX -> System A Bridge Master RX  
    // System A Bridge Master TX -> System B Bridge Slave RX
    assign b_bridge_master_rx = a_bridge_slave_tx;    // A slave -> B master
    assign a_bridge_slave_rx  = b_bridge_master_tx;   // B master -> A slave
    assign a_bridge_master_rx = b_bridge_slave_tx;    // B slave -> A master
    assign b_bridge_slave_rx  = a_bridge_master_tx;   // A master -> B slave

    //--------------------------------------------------------------------------
    // Test Control Variables
    //--------------------------------------------------------------------------
    integer test_num;
    integer errors;
    reg [DATA_WIDTH-1:0] expected_data;
    reg [DATA_WIDTH-1:0] read_data;

    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // System A Instantiation
    //==========================================================================
    
    // System A - Master 1 (Regular Master with local BRAM)
    master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH),
        .LOCAL_MEM_ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH),
        .LOCAL_MEM_SIZE(2048)
    ) sys_a_master1 (
        .clk(clk), .rstn(rstn),
        .dwdata(a_d1_wdata), .drdata(a_d1_rdata), .daddr(a_d1_addr),
        .dvalid(a_d1_valid), .dready(a_d1_ready), .dmode(a_d1_mode),
        .mrdata(a_m1_rdata), .mwdata(a_m1_wdata), .mmode(a_m1_mode),
        .mvalid(a_m1_mvalid), .svalid(a_m1_svalid),
        .mbreq(a_m1_breq), .mbgrant(a_m1_bgrant), .msplit(a_m1_split), .ack(a_m1_ack),
        .lmem_wen(a_m1_lmem_wen), .lmem_ren(a_m1_lmem_ren), .lmem_addr(a_m1_lmem_addr),
        .lmem_wdata(a_m1_lmem_wdata), .lmem_rdata(a_m1_lmem_rdata), .lmem_rvalid(a_m1_lmem_rvalid)
    );

    // System A - Master 2 (Bus Bridge Master)
    bus_bridge_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH),
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .LOCAL_MEM_SIZE(2048),
        .LOCAL_MEM_ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH)
    ) sys_a_bridge_master (
        .clk(clk), .rstn(rstn),
        .mrdata(a_m2_rdata), .mwdata(a_m2_wdata), .mmode(a_m2_mode),
        .mvalid(a_m2_mvalid), .svalid(a_m2_svalid),
        .mbreq(a_m2_breq), .mbgrant(a_m2_bgrant), .msplit(a_m2_split), .ack(a_m2_ack),
        .lmem_wen(a_m2_lmem_wen), .lmem_ren(a_m2_lmem_ren), .lmem_addr(a_m2_lmem_addr),
        .lmem_wdata(a_m2_lmem_wdata), .lmem_rdata(a_m2_lmem_rdata), .lmem_rvalid(a_m2_lmem_rvalid),
        .u_tx(a_bridge_master_tx), .u_rx(a_bridge_master_rx)
    );

    // System A - Slave 1 (2KB memory)
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .MEM_SIZE(2048)
    ) sys_a_slave1 (
        .clk(clk), .rstn(rstn),
        .swdata(a_s1_wdata), .srdata(a_s1_rdata),
        .smode(a_s1_mode), .mvalid(a_s1_mvalid),
        .split_grant(1'b0),
        .svalid(a_s1_svalid), .sready(a_s1_ready), .ssplit()
    );

    // System A - Slave 2 (4KB memory)
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .MEM_SIZE(4096)
    ) sys_a_slave2 (
        .clk(clk), .rstn(rstn),
        .swdata(a_s2_wdata), .srdata(a_s2_rdata),
        .smode(a_s2_mode), .mvalid(a_s2_mvalid),
        .split_grant(1'b0),
        .svalid(a_s2_svalid), .sready(a_s2_ready), .ssplit()
    );

    // System A - Slave 3 (Bus Bridge Slave)
    bus_bridge_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .LOCAL_MEM_SIZE(2048),
        .BRIDGE_ENABLE(1)
    ) sys_a_bridge_slave (
        .clk(clk), .rstn(rstn),
        .swdata(a_s3_wdata), .srdata(a_s3_rdata),
        .smode(a_s3_mode), .mvalid(a_s3_mvalid),
        .split_grant(a_split_grant),
        .svalid(a_s3_svalid), .sready(a_s3_ready), .ssplit(a_s3_split),
        .u_tx(a_bridge_slave_tx), .u_rx(a_bridge_slave_rx)
    );

    // System A Bus
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .SLAVE1_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) sys_a_bus (
        .clk(clk), .rstn(rstn),
        // Master 1
        .m1_wdata(a_m1_wdata), .m1_rdata(a_m1_rdata), .m1_mode(a_m1_mode),
        .m1_mvalid(a_m1_mvalid), .m1_svalid(a_m1_svalid),
        .m1_breq(a_m1_breq), .m1_bgrant(a_m1_bgrant), .m1_split(a_m1_split), .m1_ack(a_m1_ack),
        // Master 2
        .m2_wdata(a_m2_wdata), .m2_rdata(a_m2_rdata), .m2_mode(a_m2_mode),
        .m2_mvalid(a_m2_mvalid), .m2_svalid(a_m2_svalid),
        .m2_breq(a_m2_breq), .m2_bgrant(a_m2_bgrant), .m2_split(a_m2_split), .m2_ack(a_m2_ack),
        // Slave 1
        .s1_wdata(a_s1_wdata), .s1_rdata(a_s1_rdata), .s1_mode(a_s1_mode),
        .s1_mvalid(a_s1_mvalid), .s1_svalid(a_s1_svalid), .s1_ready(a_s1_ready),
        // Slave 2
        .s2_wdata(a_s2_wdata), .s2_rdata(a_s2_rdata), .s2_mode(a_s2_mode),
        .s2_mvalid(a_s2_mvalid), .s2_svalid(a_s2_svalid), .s2_ready(a_s2_ready),
        // Slave 3
        .s3_wdata(a_s3_wdata), .s3_rdata(a_s3_rdata), .s3_mode(a_s3_mode),
        .s3_mvalid(a_s3_mvalid), .s3_svalid(a_s3_svalid), .s3_ready(a_s3_ready),
        .s3_split(a_s3_split), .s3_split_grant(a_split_grant)
    );

    //==========================================================================
    // System B Instantiation (Identical to System A)
    //==========================================================================
    
    // System B - Master 1 (Regular Master with local BRAM)
    master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH),
        .LOCAL_MEM_ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH),
        .LOCAL_MEM_SIZE(2048)
    ) sys_b_master1 (
        .clk(clk), .rstn(rstn),
        .dwdata(b_d1_wdata), .drdata(b_d1_rdata), .daddr(b_d1_addr),
        .dvalid(b_d1_valid), .dready(b_d1_ready), .dmode(b_d1_mode),
        .mrdata(b_m1_rdata), .mwdata(b_m1_wdata), .mmode(b_m1_mode),
        .mvalid(b_m1_mvalid), .svalid(b_m1_svalid),
        .mbreq(b_m1_breq), .mbgrant(b_m1_bgrant), .msplit(b_m1_split), .ack(b_m1_ack),
        .lmem_wen(b_m1_lmem_wen), .lmem_ren(b_m1_lmem_ren), .lmem_addr(b_m1_lmem_addr),
        .lmem_wdata(b_m1_lmem_wdata), .lmem_rdata(b_m1_lmem_rdata), .lmem_rvalid(b_m1_lmem_rvalid)
    );

    // System B - Master 2 (Bus Bridge Master)
    bus_bridge_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(MAX_SLAVE_ADDR_WIDTH),
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .LOCAL_MEM_SIZE(2048),
        .LOCAL_MEM_ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH)
    ) sys_b_bridge_master (
        .clk(clk), .rstn(rstn),
        .mrdata(b_m2_rdata), .mwdata(b_m2_wdata), .mmode(b_m2_mode),
        .mvalid(b_m2_mvalid), .svalid(b_m2_svalid),
        .mbreq(b_m2_breq), .mbgrant(b_m2_bgrant), .msplit(b_m2_split), .ack(b_m2_ack),
        .lmem_wen(b_m2_lmem_wen), .lmem_ren(b_m2_lmem_ren), .lmem_addr(b_m2_lmem_addr),
        .lmem_wdata(b_m2_lmem_wdata), .lmem_rdata(b_m2_lmem_rdata), .lmem_rvalid(b_m2_lmem_rvalid),
        .u_tx(b_bridge_master_tx), .u_rx(b_bridge_master_rx)
    );

    // System B - Slave 1 (2KB memory)
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .MEM_SIZE(2048)
    ) sys_b_slave1 (
        .clk(clk), .rstn(rstn),
        .swdata(b_s1_wdata), .srdata(b_s1_rdata),
        .smode(b_s1_mode), .mvalid(b_s1_mvalid),
        .split_grant(1'b0),
        .svalid(b_s1_svalid), .sready(b_s1_ready), .ssplit()
    );

    // System B - Slave 2 (4KB memory)
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .MEM_SIZE(4096)
    ) sys_b_slave2 (
        .clk(clk), .rstn(rstn),
        .swdata(b_s2_wdata), .srdata(b_s2_rdata),
        .smode(b_s2_mode), .mvalid(b_s2_mvalid),
        .split_grant(1'b0),
        .svalid(b_s2_svalid), .sready(b_s2_ready), .ssplit()
    );

    // System B - Slave 3 (Bus Bridge Slave)
    bus_bridge_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .LOCAL_MEM_SIZE(2048),
        .BRIDGE_ENABLE(1)
    ) sys_b_bridge_slave (
        .clk(clk), .rstn(rstn),
        .swdata(b_s3_wdata), .srdata(b_s3_rdata),
        .smode(b_s3_mode), .mvalid(b_s3_mvalid),
        .split_grant(b_split_grant),
        .svalid(b_s3_svalid), .sready(b_s3_ready), .ssplit(b_s3_split),
        .u_tx(b_bridge_slave_tx), .u_rx(b_bridge_slave_rx)
    );

    // System B Bus
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .SLAVE1_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) sys_b_bus (
        .clk(clk), .rstn(rstn),
        // Master 1
        .m1_wdata(b_m1_wdata), .m1_rdata(b_m1_rdata), .m1_mode(b_m1_mode),
        .m1_mvalid(b_m1_mvalid), .m1_svalid(b_m1_svalid),
        .m1_breq(b_m1_breq), .m1_bgrant(b_m1_bgrant), .m1_split(b_m1_split), .m1_ack(b_m1_ack),
        // Master 2
        .m2_wdata(b_m2_wdata), .m2_rdata(b_m2_rdata), .m2_mode(b_m2_mode),
        .m2_mvalid(b_m2_mvalid), .m2_svalid(b_m2_svalid),
        .m2_breq(b_m2_breq), .m2_bgrant(b_m2_bgrant), .m2_split(b_m2_split), .m2_ack(b_m2_ack),
        // Slave 1
        .s1_wdata(b_s1_wdata), .s1_rdata(b_s1_rdata), .s1_mode(b_s1_mode),
        .s1_mvalid(b_s1_mvalid), .s1_svalid(b_s1_svalid), .s1_ready(b_s1_ready),
        // Slave 2
        .s2_wdata(b_s2_wdata), .s2_rdata(b_s2_rdata), .s2_mode(b_s2_mode),
        .s2_mvalid(b_s2_mvalid), .s2_svalid(b_s2_svalid), .s2_ready(b_s2_ready),
        // Slave 3
        .s3_wdata(b_s3_wdata), .s3_rdata(b_s3_rdata), .s3_mode(b_s3_mode),
        .s3_mvalid(b_s3_mvalid), .s3_svalid(b_s3_svalid), .s3_ready(b_s3_ready),
        .s3_split(b_s3_split), .s3_split_grant(b_split_grant)
    );

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Task: System A Master 1 Write
    task sys_a_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            $display("[%0t] SYS_A M1: Bus write to addr=0x%04h, data=0x%02h", $time, addr, data);
            @(posedge clk);
            a_d1_addr  = addr;
            a_d1_wdata = data;
            a_d1_mode  = 1'b1;  // Write
            a_d1_valid = 1'b1;
            @(posedge clk);
            a_d1_valid = 1'b0;
            // Wait for ready
            wait(a_d1_ready);
            @(posedge clk);
            $display("[%0t] SYS_A M1: Bus write complete", $time);
        end
    endtask

    // Task: System A Master 1 Read
    task sys_a_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            $display("[%0t] SYS_A M1: Bus read from addr=0x%04h", $time, addr);
            @(posedge clk);
            a_d1_addr  = addr;
            a_d1_mode  = 1'b0;  // Read
            a_d1_valid = 1'b1;
            @(posedge clk);
            a_d1_valid = 1'b0;
            // Wait for ready
            wait(a_d1_ready);
            data = a_d1_rdata;
            @(posedge clk);
            $display("[%0t] SYS_A M1: Bus read complete, data=0x%02h", $time, data);
        end
    endtask

    // Task: System B Master 1 Write
    task sys_b_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            $display("[%0t] SYS_B M1: Bus write to addr=0x%04h, data=0x%02h", $time, addr, data);
            @(posedge clk);
            b_d1_addr  = addr;
            b_d1_wdata = data;
            b_d1_mode  = 1'b1;  // Write
            b_d1_valid = 1'b1;
            @(posedge clk);
            b_d1_valid = 1'b0;
            // Wait for ready
            wait(b_d1_ready);
            @(posedge clk);
            $display("[%0t] SYS_B M1: Bus write complete", $time);
        end
    endtask

    // Task: System B Master 1 Read
    task sys_b_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            $display("[%0t] SYS_B M1: Bus read from addr=0x%04h", $time, addr);
            @(posedge clk);
            b_d1_addr  = addr;
            b_d1_mode  = 1'b0;  // Read
            b_d1_valid = 1'b1;
            @(posedge clk);
            b_d1_valid = 1'b0;
            // Wait for ready
            wait(b_d1_ready);
            data = b_d1_rdata;
            @(posedge clk);
            $display("[%0t] SYS_B M1: Bus read complete, data=0x%02h", $time, data);
        end
    endtask

    // Task: Wait for UART transmission with timeout
    task wait_uart_cycles;
        input integer cycles;
        begin
            $display("[%0t] Waiting %0d clock cycles for UART...", $time, cycles);
            repeat(cycles) @(posedge clk);
            $display("[%0t] UART wait complete", $time);
        end
    endtask

    //==========================================================================
    // Monitor UART lines
    //==========================================================================
    always @(posedge clk) begin
        // Monitor A bridge slave TX
        if (a_bridge_slave_tx == 0 && sys_a_bridge_slave.uart_module.tx_busy)
            $display("[%0t] UART_A_SLAVE_TX: START BIT detected", $time);
        
        // Monitor B bridge master RX activity
        if (sys_b_bridge_master.u_rx_ready)
            $display("[%0t] UART_B_MASTER_RX: Data received", $time);
            
        // Monitor B bridge slave TX  
        if (b_bridge_slave_tx == 0 && sys_b_bridge_slave.uart_module.tx_busy)
            $display("[%0t] UART_B_SLAVE_TX: START BIT detected", $time);
            
        // Monitor A bridge master RX activity
        if (sys_a_bridge_master.u_rx_ready)
            $display("[%0t] UART_A_MASTER_RX: Data received", $time);
    end

    //==========================================================================
    // Main Test Sequence - CROSS-SYSTEM BRIDGE TESTS ONLY
    //==========================================================================
    initial begin
        // Initialize all signals
        rstn = 0;
        errors = 0;
        
        // System A signals
        a_d1_wdata = 0; a_d1_addr = 0; a_d1_valid = 0; a_d1_mode = 0;
        a_m1_lmem_wen = 0; a_m1_lmem_ren = 0; a_m1_lmem_addr = 0; a_m1_lmem_wdata = 0;
        a_m2_lmem_wen = 0; a_m2_lmem_ren = 0; a_m2_lmem_addr = 0; a_m2_lmem_wdata = 0;
        
        // System B signals
        b_d1_wdata = 0; b_d1_addr = 0; b_d1_valid = 0; b_d1_mode = 0;
        b_m1_lmem_wen = 0; b_m1_lmem_ren = 0; b_m1_lmem_addr = 0; b_m1_lmem_wdata = 0;
        b_m2_lmem_wen = 0; b_m2_lmem_ren = 0; b_m2_lmem_addr = 0; b_m2_lmem_wdata = 0;
        
        // Start
        $display("\n");
        $display("================================================================");
        $display("   Cross-System Bridge Focused Testbench Started");
        $display("================================================================");
        $display("UART_CLOCKS_PER_PULSE = %0d", UART_CLOCKS_PER_PULSE);
        $display("Expected UART bit time = %0d clock cycles", UART_CLOCKS_PER_PULSE);
        $display("Expected UART byte time (10 bits) = %0d clock cycles", UART_CLOCKS_PER_PULSE * 10);
        $display("Expected UART 21-bit frame time = %0d clock cycles", UART_CLOCKS_PER_PULSE * 23);
        $display("================================================================\n");
        
        // Reset sequence
        repeat(10) @(posedge clk);
        rstn = 1;
        repeat(10) @(posedge clk);

        //======================================================================
        // TEST 1: First verify LOCAL transactions work (sanity check)
        //======================================================================
        $display("\n========== TEST 1: Local Slave 1 Sanity Check ==========\n");
        
        // Write to System B Slave 1 directly (local)
        sys_b_write(16'h0100, 8'hAA);
        repeat(5) @(posedge clk);
        
        // Read back from System B Slave 1 directly (local)
        sys_b_read(16'h0100, read_data);
        
        if (read_data == 8'hAA) begin
            $display("PASS: Local B->S1 write/read works (0x%02h)", read_data);
        end else begin
            $display("FAIL: Local B->S1 expected 0xAA, got 0x%02h", read_data);
            errors = errors + 1;
        end

        repeat(20) @(posedge clk);

        //======================================================================
        // TEST 2: Cross-System Write A -> B via Bridge
        //======================================================================
        $display("\n========== TEST 2: Cross-System Write A -> B ==========\n");
        $display("Path: A_M1 -> A_S3_bridge (addr 0x2800+) -> UART -> B_bridge_master -> B_S1");
        $display("");
        
        // Address 0x2800 = Slave 3 with MSB of slave addr = 1 (bridge mode)
        // Slave 3 address space: 0x2000-0x2FFF
        // Local:  0x2000-0x27FF (MSB=0 within slave)
        // Bridge: 0x2800-0x2FFF (MSB=1 within slave)
        
        // First verify B_S1 target location is empty
        $display("Step 1: Verify target location in B_S1 is initially 0x00...");
        sys_b_read(16'h0200, read_data);
        $display("        B_S1[0x0200] = 0x%02h (before bridge write)", read_data);
        
        repeat(10) @(posedge clk);
        
        // Write 0xBB to A's bridge slave (bridge mode) -> should go to B's S1
        // Bridge slave addr 0x800 + bridge bit = goes to remote S1 addr 0x000
        $display("");
        $display("Step 2: A_M1 writing 0xBB to A_S3_bridge at addr 0x2800...");
        $display("        (Bridge slave should forward to remote system)");
        sys_a_write(16'h2800, 8'hBB);
        
        // Wait for UART transmission
        // UART frame = 21 bits data + start + stop bits = ~23 bit times
        // At CLOCKS_PER_PULSE=16, that's ~368 clocks
        $display("");
        $display("Step 3: Waiting for UART transmission (~500 clocks)...");
        wait_uart_cycles(500);
        
        // Read from B_S1 to see if write arrived
        $display("");
        $display("Step 4: Reading from B_S1[0x0200] to verify bridge write...");
        sys_b_read(16'h0200, read_data);
        
        // The address mapping: bridge slave strips MSB, addr_convert maps to bus
        // Bridge slave addr 0x800 (within 12-bit space) -> strips to 0x000 on remote
        // But addr_convert then maps bb_addr to bus_addr...
        
        if (read_data == 8'hBB) begin
            $display("PASS: Cross-system A->B write succeeded! Read 0x%02h", read_data);
        end else begin
            $display("FAIL: Cross-system A->B write failed. Expected 0xBB, got 0x%02h", read_data);
            errors = errors + 1;
            $display("      Checking alternate addresses...");
            sys_b_read(16'h0000, read_data);
            $display("      B_S1[0x0000] = 0x%02h", read_data);
            sys_b_read(16'h0100, read_data);
            $display("      B_S1[0x0100] = 0x%02h", read_data);
            sys_b_read(16'h1000, read_data);
            $display("      B_S2[0x1000] = 0x%02h", read_data);
        end

        repeat(20) @(posedge clk);

        //======================================================================
        // TEST 3: Cross-System Write B -> A via Bridge
        //======================================================================
        $display("\n========== TEST 3: Cross-System Write B -> A ==========\n");
        $display("Path: B_M1 -> B_S3_bridge (addr 0x2800+) -> UART -> A_bridge_master -> A_S1");
        $display("");
        
        // Verify A_S1 target location
        $display("Step 1: Verify target location in A_S1 is initially 0x00...");
        sys_a_read(16'h0200, read_data);
        $display("        A_S1[0x0200] = 0x%02h (before bridge write)", read_data);
        
        repeat(10) @(posedge clk);
        
        // Write 0xCC from B's bridge slave -> should go to A's S1
        $display("");
        $display("Step 2: B_M1 writing 0xCC to B_S3_bridge at addr 0x2800...");
        sys_b_write(16'h2800, 8'hCC);
        
        $display("");
        $display("Step 3: Waiting for UART transmission (~500 clocks)...");
        wait_uart_cycles(500);
        
        $display("");
        $display("Step 4: Reading from A_S1[0x0200] to verify bridge write...");
        sys_a_read(16'h0200, read_data);
        
        if (read_data == 8'hCC) begin
            $display("PASS: Cross-system B->A write succeeded! Read 0x%02h", read_data);
        end else begin
            $display("FAIL: Cross-system B->A write failed. Expected 0xCC, got 0x%02h", read_data);
            errors = errors + 1;
            $display("      Checking alternate addresses...");
            sys_a_read(16'h0000, read_data);
            $display("      A_S1[0x0000] = 0x%02h", read_data);
            sys_a_read(16'h0100, read_data);
            $display("      A_S1[0x0100] = 0x%02h", read_data);
        end

        repeat(20) @(posedge clk);

        //======================================================================
        // TEST 4: Debug - Direct observation of bridge internal signals
        //======================================================================
        $display("\n========== TEST 4: Bridge Internal State Debug ==========\n");
        
        $display("A Bridge Slave state: %0d", sys_a_bridge_slave.state);
        $display("A Bridge Slave is_bridge_access: %b", sys_a_bridge_slave.is_bridge_access);
        $display("A Bridge Slave is_local_access: %b", sys_a_bridge_slave.is_local_access);
        $display("A Bridge Slave UART TX busy: %b", sys_a_bridge_slave.u_tx_busy);
        $display("");
        $display("B Bridge Master FIFO empty: %b", sys_b_bridge_master.fifo_empty);
        $display("B Bridge Master expect_rdata: %b", sys_b_bridge_master.expect_rdata);
        $display("B Bridge Master dvalid: %b", sys_b_bridge_master.dvalid);
        $display("B Bridge Master dready: %b", sys_b_bridge_master.dready);

        repeat(20) @(posedge clk);

        //======================================================================
        // FINAL SUMMARY
        //======================================================================
        $display("\n================================================================");
        $display("   Cross-System Bridge Test Complete");
        $display("================================================================");
        if (errors == 0) begin
            $display("   ALL TESTS PASSED!");
        end else begin
            $display("   ERRORS: %0d test(s) failed", errors);
        end
        $display("================================================================\n");
        
        repeat(50) @(posedge clk);
        $finish;
    end

    // Timeout
    initial begin
        #100000000;  // 100ms
        $display("\n*** TIMEOUT - Simulation exceeded time limit ***\n");
        $finish;
    end

endmodule
