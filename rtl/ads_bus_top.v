//==============================================================================
// File: ads_bus_top.v
// Description: Top-level wrapper for ADS Bus System targeting DE10-Nano FPGA
//              This module instantiates the complete 2-master, 3-slave bus system
//              with appropriate I/O connections for FPGA implementation
//
// Memory Configuration:
//   - Slave 1: 2KB (0x000-0x7FF)   - No split support
//   - Slave 2: 4KB (0x000-0xFFF)   - No split support
//   - Slave 3: 4KB (0x000-0xFFF)   - SPLIT transaction support
//
// Target Device: Intel Cyclone V 5CSEBA6U23I7 (DE10-Nano)
// Clock Frequency: 50 MHz (DE10-Nano on-board oscillator)
//==============================================================================
// Date: 2025-10-14
//==============================================================================

`timescale 1ns / 1ps

module ads_bus_top (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        FPGA_CLK1_50,        // 50 MHz clock from DE10-Nano
    input  wire        KEY0,                // Reset button (active low)
    
    //--------------------------------------------------------------------------
    // LEDs for Status Indication
    //--------------------------------------------------------------------------
    output wire [7:0]  LED,                 // 8 LEDs on DE10-Nano
    
    //--------------------------------------------------------------------------
    // GPIO for Master 1 Interface (optional external connection)
    //--------------------------------------------------------------------------
    output wire        GPIO_M1_RDATA,       // Master 1 read data
    input  wire        GPIO_M1_WDATA,       // Master 1 write data
    input  wire        GPIO_M1_MODE,        // Master 1 mode (0=read, 1=write)
    input  wire        GPIO_M1_MVALID,      // Master 1 valid
    output wire        GPIO_M1_SVALID,      // Master 1 slave valid
    input  wire        GPIO_M1_BREQ,        // Master 1 bus request
    output wire        GPIO_M1_BGRANT,      // Master 1 bus grant
    output wire        GPIO_M1_ACK,         // Master 1 acknowledge
    output wire        GPIO_M1_SPLIT,       // Master 1 split
    
    //--------------------------------------------------------------------------
    // GPIO for Master 2 Interface (optional external connection)
    //--------------------------------------------------------------------------
    output wire        GPIO_M2_RDATA,       // Master 2 read data
    input  wire        GPIO_M2_WDATA,       // Master 2 write data
    input  wire        GPIO_M2_MODE,        // Master 2 mode
    input  wire        GPIO_M2_MVALID,      // Master 2 valid
    output wire        GPIO_M2_SVALID,      // Master 2 slave valid
    input  wire        GPIO_M2_BREQ,        // Master 2 bus request
    output wire        GPIO_M2_BGRANT,      // Master 2 bus grant
    output wire        GPIO_M2_ACK,         // Master 2 acknowledge
    output wire        GPIO_M2_SPLIT        // Master 2 split
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    
    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    wire clk;
    wire rstn;
    
    // Synchronize reset
    reg [2:0] reset_sync;
    
    //--------------------------------------------------------------------------
    // Clock and Reset Management
    //--------------------------------------------------------------------------
    assign clk = FPGA_CLK1_50;
    
    // Synchronize and debounce reset button (active low button)
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], KEY0};
    end
    
    assign rstn = reset_sync[2];  // Use synchronized reset
    
    //--------------------------------------------------------------------------
    // Internal Test Pattern Generator
    //--------------------------------------------------------------------------
    // This generator creates simple test transactions to exercise the bus system
    // during synthesis and FPGA implementation. It can be overridden by GPIO inputs.
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            test_state <= TP_IDLE;
            test_counter <= 16'd0;
            test_data <= 8'h00;
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dvalid <= 1'b0;
            m1_dmode <= 1'b0;
            m2_dwdata <= 8'h00;
            m2_daddr <= 16'h0000;
            m2_dvalid <= 1'b0;
            m2_dmode <= 1'b0;
        end else begin
            // Default: no new transactions
            m1_dvalid <= 1'b0;
            m2_dvalid <= 1'b0;
            
            // Counter for delays and pattern generation
            test_counter <= test_counter + 1'b1;
            
            case (test_state)
                TP_IDLE: begin
                    // Wait for reset to stabilize, then start test sequence
                    if (test_counter > 16'd100) begin
                        test_state <= TP_M1_WRITE;
                        test_counter <= 16'd0;
                        test_data <= 8'hA5;  // Test pattern
                    end
                end
                
                TP_M1_WRITE: begin
                    // Master 1 writes to Slave 1 (address 0x0010)
                    m1_daddr <= 16'h0010;
                    m1_dwdata <= test_data;
                    m1_dmode <= 1'b1;  // Write mode
                    m1_dvalid <= 1'b1;
                    test_state <= TP_M1_WAIT;
                    test_counter <= 16'd0;
                end
                
                TP_M1_WAIT: begin
                    // Wait for Master 1 transaction to complete
                    if (m1_dready || test_counter > 16'd1000) begin
                        test_state <= TP_M1_READ;
                        test_counter <= 16'd0;
                    end
                end
                
                TP_M1_READ: begin
                    // Master 1 reads from Slave 1 (same address)
                    m1_daddr <= 16'h0010;
                    m1_dmode <= 1'b0;  // Read mode
                    m1_dvalid <= 1'b1;
                    test_state <= TP_M1_RWAIT;
                    test_counter <= 16'd0;
                end
                
                TP_M1_RWAIT: begin
                    // Wait for Master 1 read to complete
                    if (m1_dready || test_counter > 16'd1000) begin
                        test_state <= TP_M2_WRITE;
                        test_counter <= 16'd0;
                        test_data <= 8'h5A;  // Different test pattern
                    end
                end
                
                TP_M2_WRITE: begin
                    // Master 2 writes to Slave 2 (address 0x0820)
                    m2_daddr <= 16'h0820;
                    m2_dwdata <= test_data;
                    m2_dmode <= 1'b1;  // Write mode
                    m2_dvalid <= 1'b1;
                    test_state <= TP_M2_WAIT;
                    test_counter <= 16'd0;
                end
                
                TP_M2_WAIT: begin
                    // Wait for Master 2 transaction to complete
                    if (m2_dready || test_counter > 16'd1000) begin
                        test_state <= TP_M2_READ;
                        test_counter <= 16'd0;
                    end
                end
                
                TP_M2_READ: begin
                    // Master 2 reads from Slave 2 (same address)
                    m2_daddr <= 16'h0820;
                    m2_dmode <= 1'b0;  // Read mode
                    m2_dvalid <= 1'b1;
                    test_state <= TP_M2_RWAIT;
                    test_counter <= 16'd0;
                end
                
                TP_M2_RWAIT: begin
                    // Wait for Master 2 read to complete
                    if (m2_dready || test_counter > 16'd1000) begin
                        test_state <= TP_DONE;
                        test_counter <= 16'd0;
                    end
                end
                
                TP_DONE: begin
                    // Test sequence complete - loop back after delay
                    if (test_counter > 16'd5000) begin
                        test_state <= TP_M1_WRITE;
                        test_counter <= 16'd0;
                        test_data <= test_data + 8'h01;  // Increment pattern
                    end
                end
                
                default: test_state <= TP_IDLE;
            endcase
        end
    end
    
    //--------------------------------------------------------------------------
    // Status LED Assignments
    //--------------------------------------------------------------------------
    // Internal Master-to-Bus Signals
    //--------------------------------------------------------------------------
    // Master 1 to Bus
    wire m1_rdata, m1_wdata, m1_mode, m1_mvalid, m1_svalid;
    wire m1_breq, m1_bgrant, m1_ack, m1_split;
    
    // Master 2 to Bus
    wire m2_rdata, m2_wdata, m2_mode, m2_mvalid, m2_svalid;
    wire m2_breq, m2_bgrant, m2_ack, m2_split;
    
    // Internal bus signals for slaves
    wire s1_rdata, s1_wdata, s1_mode, s1_mvalid, s1_svalid, s1_ready;
    wire s2_rdata, s2_wdata, s2_mode, s2_mvalid, s2_svalid, s2_ready;
    wire s3_rdata, s3_wdata, s3_mode, s3_mvalid, s3_svalid, s3_ready;
    wire s3_split;
    wire split_grant;
    
    //--------------------------------------------------------------------------
    // Test Pattern Generator Signals
    //--------------------------------------------------------------------------
    // Master 1 device signals (internal test pattern generator)
    reg [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg [ADDR_WIDTH-1:0] m1_daddr;
    reg m1_dvalid;
    wire m1_dready;
    reg m1_dmode;
    
    // Master 2 device signals (internal test pattern generator)
    reg [DATA_WIDTH-1:0] m2_dwdata;
    wire [DATA_WIDTH-1:0] m2_drdata;
    reg [ADDR_WIDTH-1:0] m2_daddr;
    reg m2_dvalid;
    wire m2_dready;
    reg m2_dmode;
    
    // Test pattern generator state
    reg [3:0] test_state;
    reg [15:0] test_counter;
    reg [7:0] test_data;
    
    // Test pattern generator states
    localparam TP_IDLE     = 4'd0;
    localparam TP_M1_WRITE = 4'd1;
    localparam TP_M1_WAIT  = 4'd2;
    localparam TP_M1_READ  = 4'd3;
    localparam TP_M1_RWAIT = 4'd4;
    localparam TP_M2_WRITE = 4'd5;
    localparam TP_M2_WAIT  = 4'd6;
    localparam TP_M2_READ  = 4'd7;
    localparam TP_M2_RWAIT = 4'd8;
    localparam TP_DONE     = 4'd9;
    
    //--------------------------------------------------------------------------
    // Status LED Assignments
    //--------------------------------------------------------------------------
    assign LED[0] = rstn;                   // Reset status
    assign LED[1] = m1_bgrant;              // Master 1 bus grant
    assign LED[2] = m2_bgrant;              // Master 2 bus grant
    assign LED[3] = m1_ack;                 // Master 1 acknowledge
    assign LED[4] = m2_ack;                 // Master 2 acknowledge
    assign LED[5] = m1_split;               // Master 1 split
    assign LED[6] = m2_split;               // Master 2 split
    assign LED[7] = 1'b0;                   // Reserved
    
    //--------------------------------------------------------------------------
    // GPIO Output Assignments
    //--------------------------------------------------------------------------
    assign GPIO_M1_RDATA  = m1_rdata;
    assign GPIO_M1_SVALID = m1_svalid;
    assign GPIO_M1_BGRANT = m1_bgrant;
    assign GPIO_M1_ACK    = m1_ack;
    assign GPIO_M1_SPLIT  = m1_split;
    
    assign GPIO_M2_RDATA  = m2_rdata;
    assign GPIO_M2_SVALID = m2_svalid;
    assign GPIO_M2_BGRANT = m2_bgrant;
    assign GPIO_M2_ACK    = m2_ack;
    assign GPIO_M2_SPLIT  = m2_split;
    
    //--------------------------------------------------------------------------
    // Master Port 1 Instantiation
    //--------------------------------------------------------------------------
    // Connected to internal test pattern generator
    // Can be overridden by external GPIO if needed
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)  // Use max slave addr width
    ) master1_port (
        .clk(clk),
        .rstn(rstn),
        
        // Device interface - connected to internal test pattern generator
        .dwdata(m1_dwdata),          // From test pattern generator
        .drdata(m1_drdata),          // To test pattern generator
        .daddr(m1_daddr),            // From test pattern generator
        .dvalid(m1_dvalid),          // From test pattern generator
        .dready(m1_dready),          // To test pattern generator
        .dmode(m1_dmode),            // From test pattern generator
        
        // Bus interface
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
    // Master Port 2 Instantiation
    //--------------------------------------------------------------------------
    // Connected to internal test pattern generator
    // Can be overridden by external GPIO if needed
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)  // Use max slave addr width
    ) master2_port (
        .clk(clk),
        .rstn(rstn),
        
        // Device interface - connected to internal test pattern generator
        .dwdata(m2_dwdata),          // From test pattern generator
        .drdata(m2_drdata),          // To test pattern generator
        .daddr(m2_daddr),            // From test pattern generator
        .dvalid(m2_dvalid),          // From test pattern generator
        .dready(m2_dready),          // To test pattern generator
        .dmode(m2_dmode),            // From test pattern generator
        
        // Bus interface
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
    
    //--------------------------------------------------------------------------
    // Bus Interconnect Instantiation
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
        
        // Master 1 interface (from master1_port)
        .m1_rdata(m1_rdata),
        .m1_wdata(m1_wdata),
        .m1_mode(m1_mode),
        .m1_mvalid(m1_mvalid),
        .m1_svalid(m1_svalid),
        .m1_breq(m1_breq),
        .m1_bgrant(m1_bgrant),
        .m1_ack(m1_ack),
        .m1_split(m1_split),
        
        // Master 2 interface (from master2_port)
        .m2_rdata(m2_rdata),
        .m2_wdata(m2_wdata),
        .m2_mode(m2_mode),
        .m2_mvalid(m2_mvalid),
        .m2_svalid(m2_svalid),
        .m2_breq(m2_breq),
        .m2_bgrant(m2_bgrant),
        .m2_ack(m2_ack),
        .m2_split(m2_split),
        
        // Slave 1 interface
        .s1_rdata(s1_rdata),
        .s1_wdata(s1_wdata),
        .s1_mode(s1_mode),
        .s1_mvalid(s1_mvalid),
        .s1_svalid(s1_svalid),
        .s1_ready(s1_ready),
        
        // Slave 2 interface
        .s2_rdata(s2_rdata),
        .s2_wdata(s2_wdata),
        .s2_mode(s2_mode),
        .s2_mvalid(s2_mvalid),
        .s2_svalid(s2_svalid),
        .s2_ready(s2_ready),
        
        // Slave 3 interface
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
    // Slave 1 Instantiation (2KB, No Split)
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
        .ssplit(),              // Not connected
        .split_grant(1'b0)      // Not used
    );
    
    //--------------------------------------------------------------------------
    // Slave 2 Instantiation (4KB, No Split)
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
        .ssplit(),              // Not connected
        .split_grant(1'b0)      // Not used
    );
    
    //--------------------------------------------------------------------------
    // // Slave 3 Instantiation (4KB, Split Enabled)
    // //--------------------------------------------------------------------------
    // slave #(
    //     .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .SPLIT_EN(1),
    //     .MEM_SIZE(4096)
    // ) slave3_inst (
    //     .clk(clk),
    //     .rstn(rstn),
    //     .srdata(s3_rdata),
    //     .swdata(s3_wdata),
    //     .smode(s3_mode),
    //     .svalid(s3_svalid),
    //     .mvalid(s3_mvalid),
    //     .sready(s3_ready),
    //     .ssplit(s3_split),
    //     .split_grant(split_grant)
    // );

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
