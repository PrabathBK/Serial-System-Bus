//==============================================================================
// File: de0_nano_demo_top.v
// Description: Demonstration Top Module for ADS Bus System on DE0-Nano
//              
// Features:
//   - Internal communication: Master 1 -> Slave 1, Slave 2
//   - External communication: Master 1 -> Slave 3 (Bus Bridge) -> UART -> System B
//   - User interface via switches, buttons, and LEDs
//
// DE0-Nano Resources Used:
//   - CLOCK_50: 50 MHz system clock
//   - KEY[1:0]: Push buttons (active low)
//   - SW[3:0]:  DIP switches for data/address input
//   - LED[7:0]: Status and data display
//   - GPIO_0:   UART TX/RX for bus bridge
//
// Operation Modes:
//   - SW[3:2] = 00: Write mode to Slave 1 (internal)
//   - SW[3:2] = 01: Write mode to Slave 2 (internal)
//   - SW[3:2] = 10: Write mode to Slave 3 (bus bridge - external)
//   - SW[3:2] = 11: Read mode (from last written slave)
//
//   - KEY[0]: Reset (active low)
//   - KEY[1]: Execute transaction (active low, trigger on release)
//
//   - SW[1:0]: Data input (lower 2 bits, combined with counter for 8-bit)
//
// LED Display:
//   - Normal: Shows last read data (8 bits)
//   - During transaction: Shows status
//
// Author: ADS Bus System
// Target: Terasic DE0-Nano (Cyclone IV EP4CE22F17C6N)
// Date: 2025-12-02
//==============================================================================

`timescale 1ns / 1ps

module de0_nano_demo_top (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        CLOCK_50,            // 50 MHz clock
    
    //--------------------------------------------------------------------------
    // Push Buttons (directly active low)
    //--------------------------------------------------------------------------
    input  wire [1:0]  KEY,                 // KEY[0]=Reset, KEY[1]=Execute
    
    //--------------------------------------------------------------------------
    // DIP Switches
    //--------------------------------------------------------------------------
    input  wire [3:0]  SW,                  // Mode and data input
    
    //--------------------------------------------------------------------------
    // LEDs
    //--------------------------------------------------------------------------
    output reg  [7:0]  LED,                 // Data/status display
    
    //--------------------------------------------------------------------------
    // GPIO Header 0 - UART for Bus Bridge
    //--------------------------------------------------------------------------
    // Bridge Master UART (receives commands from external, executes on this bus)
    input  wire        GPIO_0_BRIDGE_M_RX,  // GPIO_0[0] - UART RX for bridge master
    output wire        GPIO_0_BRIDGE_M_TX,  // GPIO_0[1] - UART TX for bridge master
    
    // Bridge Slave UART (sends commands to external system)
    input  wire        GPIO_0_BRIDGE_S_RX,  // GPIO_0[2] - UART RX for bridge slave
    output wire        GPIO_0_BRIDGE_S_TX   // GPIO_0[3] - UART TX for bridge slave
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB (bus bridge slave)
    parameter BB_ADDR_WIDTH = 12;          // Bus bridge address width
    
    // UART baud rate: 9600 bps @ 50MHz -> 50000000/9600 = 5208
    parameter UART_CLOCKS_PER_PULSE = 5208;
    
    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    wire clk;
    wire rstn;
    
    // Synchronized and debounced inputs
    reg [2:0] key0_sync, key1_sync;
    reg [3:0] sw_sync;
    wire key0_stable, key1_stable;
    reg key1_prev;
    wire key1_release;  // Trigger on button release
    
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    assign clk = CLOCK_50;
    
    // Synchronize reset button (KEY[0], active low)
    always @(posedge clk) begin
        key0_sync <= {key0_sync[1:0], KEY[0]};
    end
    assign rstn = key0_sync[2];  // Active low button -> active low reset
    
    // Synchronize execute button (KEY[1], active low)
    always @(posedge clk) begin
        if (!rstn) begin
            key1_sync <= 3'b111;
            key1_prev <= 1'b1;
        end else begin
            key1_sync <= {key1_sync[1:0], KEY[1]};
            key1_prev <= key1_stable;
        end
    end
    assign key1_stable = key1_sync[2];
    assign key1_release = key1_prev == 1'b0 && key1_stable == 1'b1;  // Rising edge = release
    
    // Synchronize switches
    always @(posedge clk) begin
        if (!rstn)
            sw_sync <= 4'b0;
        else
            sw_sync <= SW;
    end
    
    //--------------------------------------------------------------------------
    // Demo State Machine
    //--------------------------------------------------------------------------
    localparam ST_IDLE       = 4'd0;
    localparam ST_WRITE_WAIT = 4'd1;
    localparam ST_WRITE_DONE = 4'd2;
    localparam ST_READ_WAIT  = 4'd3;
    localparam ST_READ_DONE  = 4'd4;
    localparam ST_DISPLAY    = 4'd5;
    
    reg [3:0] demo_state;
    reg [15:0] timeout_counter;
    reg [7:0] write_data;
    reg [15:0] target_addr;
    reg [7:0] read_data_reg;
    reg [7:0] transaction_count;
    reg [1:0] last_slave_select;
    reg [15:0] last_write_addr;  // Store last written address for read-back
    
    //--------------------------------------------------------------------------
    // Master 1 Device Interface Signals
    //--------------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg  [ADDR_WIDTH-1:0] m1_daddr;
    reg                   m1_dvalid;
    wire                  m1_dready;
    reg                   m1_dmode;
    
    //--------------------------------------------------------------------------
    // Bus Signals
    //--------------------------------------------------------------------------
    // Master 1 to Bus
    wire m1_rdata, m1_wdata, m1_mode, m1_mvalid, m1_svalid;
    wire m1_breq, m1_bgrant, m1_ack, m1_split;
    
    // Master 2 (Bus Bridge Master) to Bus
    wire m2_rdata, m2_wdata, m2_mode, m2_mvalid, m2_svalid;
    wire m2_breq, m2_bgrant, m2_ack, m2_split;
    
    // Slave 1 signals
    wire s1_rdata, s1_wdata, s1_mode, s1_mvalid, s1_svalid, s1_ready;
    
    // Slave 2 signals
    wire s2_rdata, s2_wdata, s2_mode, s2_mvalid, s2_svalid, s2_ready;
    
    // Slave 3 (Bus Bridge Slave) signals
    wire s3_rdata, s3_wdata, s3_mode, s3_mvalid, s3_svalid, s3_ready;
    wire s3_split;
    wire split_grant;
    
    //--------------------------------------------------------------------------
    // Address Generation
    // Device addressing:
    //   - Slave 1: Address 0x0xxx (device addr = 0)
    //   - Slave 2: Address 0x1xxx (device addr = 1)
    //   - Slave 3: Address 0x2xxx (device addr = 2)
    //--------------------------------------------------------------------------
    always @(*) begin
        case (sw_sync[3:2])
            2'b00: target_addr = {4'b0000, transaction_count[3:0], 8'h00}; // Slave 1
            2'b01: target_addr = {4'b0001, transaction_count[3:0], 8'h00}; // Slave 2
            2'b10: target_addr = {4'b0010, transaction_count[3:0], 8'h00}; // Slave 3 (bridge)
            2'b11: target_addr = last_write_addr;  // Read from last written address
        endcase
    end
    
    //--------------------------------------------------------------------------
    // Write Data Generation
    // Combines switch input with transaction counter for variety
    //--------------------------------------------------------------------------
    always @(*) begin
        write_data = {transaction_count[5:0], sw_sync[1:0]};
    end
    
    //--------------------------------------------------------------------------
    // Demo State Machine
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            demo_state <= ST_IDLE;
            m1_dvalid <= 1'b0;
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dmode <= 1'b0;
            timeout_counter <= 16'd0;
            read_data_reg <= 8'h00;
            transaction_count <= 8'd0;
            last_slave_select <= 2'b00;
            last_write_addr <= 16'h0000;
        end else begin
            case (demo_state)
                ST_IDLE: begin
                    m1_dvalid <= 1'b0;
                    timeout_counter <= 16'd0;
                    
                    if (key1_release) begin
                        if (sw_sync[3:2] == 2'b11) begin
                            // Read mode
                            m1_daddr <= target_addr;
                            m1_dmode <= 1'b0;  // Read
                            m1_dvalid <= 1'b1;
                            demo_state <= ST_READ_WAIT;
                        end else begin
                            // Write mode
                            m1_daddr <= target_addr;
                            m1_dwdata <= write_data;
                            m1_dmode <= 1'b1;  // Write
                            m1_dvalid <= 1'b1;
                            last_slave_select <= sw_sync[3:2];
                            last_write_addr <= target_addr;  // Save address for read-back
                            demo_state <= ST_WRITE_WAIT;
                        end
                    end
                end
                
                ST_WRITE_WAIT: begin
                    m1_dvalid <= 1'b0;  // Clear valid after one cycle
                    timeout_counter <= timeout_counter + 1'b1;
                    
                    if (m1_dready && !m1_dvalid) begin
                        demo_state <= ST_WRITE_DONE;
                    end else if (timeout_counter > 16'd50000) begin
                        // Timeout - go back to idle
                        demo_state <= ST_IDLE;
                    end
                end
                
                ST_WRITE_DONE: begin
                    transaction_count <= transaction_count + 1'b1;
                    demo_state <= ST_DISPLAY;
                end
                
                ST_READ_WAIT: begin
                    m1_dvalid <= 1'b0;
                    timeout_counter <= timeout_counter + 1'b1;
                    
                    if (m1_dready && !m1_dvalid) begin
                        read_data_reg <= m1_drdata;
                        demo_state <= ST_READ_DONE;
                    end else if (timeout_counter > 16'd50000) begin
                        demo_state <= ST_IDLE;
                    end
                end
                
                ST_READ_DONE: begin
                    transaction_count <= transaction_count + 1'b1;
                    demo_state <= ST_DISPLAY;
                end
                
                ST_DISPLAY: begin
                    // Short delay to show result
                    timeout_counter <= timeout_counter + 1'b1;
                    if (timeout_counter > 16'd1000) begin
                        demo_state <= ST_IDLE;
                    end
                end
                
                default: demo_state <= ST_IDLE;
            endcase
        end
    end
    
    //--------------------------------------------------------------------------
    // LED Display Logic
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            LED <= 8'h00;
        end else begin
            case (demo_state)
                ST_IDLE: begin
                    // Show last read data or pattern based on mode
                    if (sw_sync[3:2] == 2'b11) begin
                        LED <= read_data_reg;  // Show read data
                    end else begin
                        // Show target slave on upper LEDs, write data preview on lower
                        LED <= {2'b00, sw_sync[3:2], sw_sync[1:0], transaction_count[1:0]};
                    end
                end
                
                ST_WRITE_WAIT, ST_READ_WAIT: begin
                    // Animated busy indicator
                    LED <= {timeout_counter[12], timeout_counter[11], 
                            timeout_counter[10], timeout_counter[9],
                            m1_bgrant, m1_ack, s1_ready | s2_ready, s3_ready};
                end
                
                ST_WRITE_DONE: begin
                    LED <= 8'b10101010;  // Write complete pattern
                end
                
                ST_READ_DONE: begin
                    LED <= read_data_reg;  // Show read data immediately
                end
                
                ST_DISPLAY: begin
                    LED <= read_data_reg;  // Continue showing read data
                end
                
                default: LED <= 8'hFF;
            endcase
        end
    end
    
    //==========================================================================
    // Module Instantiations
    //==========================================================================
    
    //--------------------------------------------------------------------------
    // Master Port 1 - User controlled via buttons/switches
    //--------------------------------------------------------------------------
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master1_port (
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
    
    //--------------------------------------------------------------------------
    // Master Port 2 - Bus Bridge Master
    // Receives commands via UART from external system and executes on this bus
    //--------------------------------------------------------------------------
    bus_bridge_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) master2_bridge (
        .clk(clk),
        .rstn(rstn),
        .mrdata(m2_rdata),
        .mwdata(m2_wdata),
        .mmode(m2_mode),
        .mvalid(m2_mvalid),
        .svalid(m2_svalid),
        .mbreq(m2_breq),
        .mbgrant(m2_bgrant),
        .msplit(m2_split),
        .ack(m2_ack),
        .u_tx(GPIO_0_BRIDGE_M_TX),
        .u_rx(GPIO_0_BRIDGE_M_RX)
    );
    
    //--------------------------------------------------------------------------
    // Bus Interconnect (2 Masters, 3 Slaves)
    //--------------------------------------------------------------------------
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) bus_inst (
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
        // Master 2 (Bridge)
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
        // Slave 3 (Bridge)
        .s3_rdata(s3_rdata),
        .s3_wdata(s3_wdata),
        .s3_mode(s3_mode),
        .s3_mvalid(s3_mvalid),
        .s3_svalid(s3_svalid),
        .s3_ready(s3_ready),
        .s3_split(s3_split),
        .split_grant(split_grant)
    );
    
    //--------------------------------------------------------------------------
    // Slave 1 - Internal Memory (2KB)
    //--------------------------------------------------------------------------
    slave #(
        .ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(2048)
    ) slave1_inst (
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
    // Slave 2 - Internal Memory (4KB)
    //--------------------------------------------------------------------------
    slave #(
        .ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(0),
        .MEM_SIZE(4096)
    ) slave2_inst (
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
    // Slave 3 - Bus Bridge Slave
    // Forwards commands via UART to external system
    //--------------------------------------------------------------------------
    bus_bridge_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .UART_CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE)
    ) slave3_bridge (
        .clk(clk),
        .rstn(rstn),
        .swdata(s3_wdata),
        .smode(s3_mode),
        .mvalid(s3_mvalid),
        .split_grant(split_grant),
        .srdata(s3_rdata),
        .svalid(s3_svalid),
        .sready(s3_ready),
        .ssplit(s3_split),
        .u_tx(GPIO_0_BRIDGE_S_TX),
        .u_rx(GPIO_0_BRIDGE_S_RX)
    );

endmodule
