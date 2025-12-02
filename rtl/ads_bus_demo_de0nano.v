//==============================================================================
// File: ads_bus_demo_de0nano.v
// Description: Demo wrapper for ADS Bus System targeting DE0-Nano FPGA
//              Simplified demo with button-triggered transactions
//
// Demo Features:
//   - Press KEY0 to trigger a transaction
//   - SW[0] acts as reset (active high - directly accessible)
//   - LEDs show: [1:0] = slave number, [7:2] = last 6 bits of data
//   - Hardcoded master selection, slave target, and data pattern
//
// Target Device: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
// Clock Frequency: 50 MHz
//==============================================================================

`timescale 1ns / 1ps

module ads_bus_demo_de0nano (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        CLOCK_50,            // 50 MHz clock from DE0-Nano
    
    //--------------------------------------------------------------------------
    // Push Buttons (directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly)
    //--------------------------------------------------------------------------
    input  wire [1:0]  KEY,                 // KEY[0] = Trigger transaction (active low)
                                            // KEY[1] = Reserved
    
    //--------------------------------------------------------------------------
    // DIP Switches
    //--------------------------------------------------------------------------
    input  wire [3:0]  SW,                  // SW[0] = Reset (active high)
                                            // SW[1] = Master select (0=M1, 1=M2)
                                            // SW[2] = Mode (0=Write, 1=Read)  
                                            // SW[3] = Reserved
    
    //--------------------------------------------------------------------------
    // LEDs for Status Display
    //--------------------------------------------------------------------------
    output wire [7:0]  LED                  // LED[1:0] = Slave number (0,1,2)
                                            // LED[7:2] = Last 6 bits of data
);

    //==========================================================================
    // DEMO CONFIGURATION - EDIT THESE TO CHANGE DEMO BEHAVIOR
    //==========================================================================
    
    // Which master sends the transaction (0 = Master1, 1 = Master2)
    localparam DEMO_MASTER_SELECT = 1'b0;   // Use Master 1
    
    // Target slave for the transaction (2'b00=Slave1, 2'b01=Slave2, 2'b10=Slave3)
    localparam [1:0] DEMO_SLAVE_SELECT = 2'b01;  // Target Slave 2

    // Data pattern to send (8 bits)
    localparam [7:0] DEMO_DATA_PATTERN = 8'hA5;  // Test pattern 10100101
    
    // Memory address within the slave
    localparam [11:0] DEMO_MEM_ADDR = 12'h010;   // Address 0x010
    
    // Transaction mode (0 = Read, 1 = Write)
    localparam DEMO_MODE = 1'b1;            // Write operation
    
    //==========================================================================
    // Parameters
    //==========================================================================
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    parameter SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    parameter SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    
    //==========================================================================
    // Internal Signals
    //==========================================================================
    wire clk;
    wire rstn;
    
    // Button edge detection
    reg [2:0] key0_sync;
    wire key0_pressed;
    
    // Reset synchronization
    reg [2:0] reset_sync;
    
    //==========================================================================
    // Clock and Reset Management
    //==========================================================================
    assign clk = CLOCK_50;
    
    // Synchronize reset switch (active high on SW[0])
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], ~SW[0]};  // Invert: SW high = reset active
    end
    assign rstn = reset_sync[2];
    
    // Button edge detection for KEY0 (active low, detect falling edge)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            key0_sync <= 3'b111;
        end else begin
            key0_sync <= {key0_sync[1:0], KEY[0]};
        end
    end
    // Detect button press (falling edge)
    assign key0_pressed = (key0_sync[2:1] == 2'b10);
    
    //==========================================================================
    // Demo Transaction Controller
    //==========================================================================
    // States for demo FSM
    localparam DEMO_IDLE      = 3'd0;
    localparam DEMO_START     = 3'd1;
    localparam DEMO_WAIT      = 3'd2;
    localparam DEMO_COMPLETE  = 3'd3;
    localparam DEMO_DISPLAY   = 3'd4;
    
    reg [2:0] demo_state;
    reg [15:0] demo_counter;
    reg [7:0] display_data;
    reg [1:0] display_slave;
    reg transaction_active;
    
    // Master 1 device interface signals
    reg [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg [ADDR_WIDTH-1:0] m1_daddr;
    reg m1_dvalid;
    wire m1_dready;
    reg m1_dmode;
    
    // Master 2 device interface signals
    reg [DATA_WIDTH-1:0] m2_dwdata;
    wire [DATA_WIDTH-1:0] m2_drdata;
    reg [ADDR_WIDTH-1:0] m2_daddr;
    reg m2_dvalid;
    wire m2_dready;
    reg m2_dmode;
    
    // Build full address: {device_addr[3:0], mem_addr[11:0]}
    wire [15:0] full_address;
    assign full_address = {2'b00, DEMO_SLAVE_SELECT, DEMO_MEM_ADDR};
    
    // Demo FSM
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            demo_state <= DEMO_IDLE;
            demo_counter <= 16'd0;
            display_data <= 8'h00;
            display_slave <= 2'b00;
            transaction_active <= 1'b0;
            
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dvalid <= 1'b0;
            m1_dmode <= 1'b0;
            
            m2_dwdata <= 8'h00;
            m2_daddr <= 16'h0000;
            m2_dvalid <= 1'b0;
            m2_dmode <= 1'b0;
        end else begin
            // Default: deassert valid signals
            m1_dvalid <= 1'b0;
            m2_dvalid <= 1'b0;
            
            case (demo_state)
                DEMO_IDLE: begin
                    transaction_active <= 1'b0;
                    if (key0_pressed) begin
                        demo_state <= DEMO_START;
                        demo_counter <= 16'd0;
                    end
                end
                
                DEMO_START: begin
                    transaction_active <= 1'b1;
                    // Setup transaction based on configured master
                    if (DEMO_MASTER_SELECT == 1'b0) begin
                        // Master 1 transaction
                        m1_daddr <= full_address;
                        m1_dwdata <= DEMO_DATA_PATTERN;
                        m1_dmode <= DEMO_MODE;
                        m1_dvalid <= 1'b1;
                    end else begin
                        // Master 2 transaction
                        m2_daddr <= full_address;
                        m2_dwdata <= DEMO_DATA_PATTERN;
                        m2_dmode <= DEMO_MODE;
                        m2_dvalid <= 1'b1;
                    end
                    demo_state <= DEMO_WAIT;
                    demo_counter <= 16'd0;
                end
                
                DEMO_WAIT: begin
                    demo_counter <= demo_counter + 1'b1;
                    
                    // Check if transaction complete or timeout
                    if ((DEMO_MASTER_SELECT == 1'b0 && m1_dready) ||
                        (DEMO_MASTER_SELECT == 1'b1 && m2_dready) ||
                        (demo_counter > 16'd2000)) begin
                        demo_state <= DEMO_COMPLETE;
                    end
                end
                
                DEMO_COMPLETE: begin
                    // Capture results for display
                    display_slave <= DEMO_SLAVE_SELECT;
                    if (DEMO_MODE == 1'b0) begin
                        // Read mode - display read data
                        display_data <= (DEMO_MASTER_SELECT == 1'b0) ? m1_drdata : m2_drdata;
                    end else begin
                        // Write mode - display written data
                        display_data <= DEMO_DATA_PATTERN;
                    end
                    demo_state <= DEMO_DISPLAY;
                    demo_counter <= 16'd0;
                end
                
                DEMO_DISPLAY: begin
                    transaction_active <= 1'b0;
                    // Hold display for a while, then return to idle
                    demo_counter <= demo_counter + 1'b1;
                    if (demo_counter > 16'd50000) begin  // ~1ms at 50MHz
                        demo_state <= DEMO_IDLE;
                    end
                end
                
                default: demo_state <= DEMO_IDLE;
            endcase
        end
    end
    
    //==========================================================================
    // LED Display Assignment
    //==========================================================================
    // LED[1:0] = Slave number (0, 1, or 2)
    // LED[7:2] = Last 6 bits of data
    assign LED[1:0] = display_slave;
    assign LED[7:2] = display_data[5:0];
    
    //==========================================================================
    // Internal Bus Signals
    //==========================================================================
    // Master 1 to Bus
    wire m1_rdata, m1_wdata, m1_mode, m1_mvalid, m1_svalid;
    wire m1_breq, m1_bgrant, m1_ack, m1_split;
    
    // Master 2 to Bus
    wire m2_rdata, m2_wdata, m2_mode, m2_mvalid, m2_svalid;
    wire m2_breq, m2_bgrant, m2_ack, m2_split;
    
    // Slave interface signals
    wire s1_rdata, s1_wdata, s1_mode, s1_mvalid, s1_svalid, s1_ready;
    wire s2_rdata, s2_wdata, s2_mode, s2_mvalid, s2_svalid, s2_ready;
    wire s3_rdata, s3_wdata, s3_mode, s3_mvalid, s3_svalid, s3_ready;
    wire s3_split;
    wire split_grant;
    
    //==========================================================================
    // Master Port 1 Instantiation
    //==========================================================================
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master1_port (
        .clk(clk),
        .rstn(rstn),
        
        // Device interface
        .dwdata(m1_dwdata),
        .drdata(m1_drdata),
        .daddr(m1_daddr),
        .dvalid(m1_dvalid),
        .dready(m1_dready),
        .dmode(m1_dmode),
        
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
    
    //==========================================================================
    // Master Port 2 Instantiation
    //==========================================================================
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master2_port (
        .clk(clk),
        .rstn(rstn),
        
        // Device interface
        .dwdata(m2_dwdata),
        .drdata(m2_drdata),
        .daddr(m2_daddr),
        .dvalid(m2_dvalid),
        .dready(m2_dready),
        .dmode(m2_dmode),
        
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
    
    //==========================================================================
    // Bus Interconnect Instantiation
    //==========================================================================
    bus_m2_s3 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE1_MEM_ADDR_WIDTH(SLAVE1_MEM_ADDR_WIDTH),
        .SLAVE2_MEM_ADDR_WIDTH(SLAVE2_MEM_ADDR_WIDTH),
        .SLAVE3_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) bus_inst (
        .clk(clk),
        .rstn(rstn),
        
        // Master 1 interface
        .m1_rdata(m1_rdata),
        .m1_wdata(m1_wdata),
        .m1_mode(m1_mode),
        .m1_mvalid(m1_mvalid),
        .m1_svalid(m1_svalid),
        .m1_breq(m1_breq),
        .m1_bgrant(m1_bgrant),
        .m1_ack(m1_ack),
        .m1_split(m1_split),
        
        // Master 2 interface
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
    
    //==========================================================================
    // Slave 1 Instantiation (2KB, No Split)
    //==========================================================================
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
    
    //==========================================================================
    // Slave 2 Instantiation (4KB, No Split)
    //==========================================================================
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
    
    //==========================================================================
    // Slave 3 Instantiation (4KB, Split Enabled)
    //==========================================================================
    slave #(
        .ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(1),
        .MEM_SIZE(4096)
    ) slave3_inst (
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

endmodule
