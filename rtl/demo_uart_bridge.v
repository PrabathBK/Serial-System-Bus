//==============================================================================
// File: demo_uart_bridge.v
// Description: Unified Demo Wrapper for ADS Bus System with Bus Bridge
//              Supports both internal (local master) and external (UART bridge)
//              communication modes, selectable via switches.
//
// Target: DE0-Nano FPGA
// 
// Architecture:
//   Master 1: Local master (controlled by buttons/switches)
//   Master 2: Bus Bridge Master (receives commands via UART from external bus)
//   Slave 1:  Local memory (2KB)
//   Slave 2:  Local memory (4KB)
//   Slave 3:  Bus Bridge Slave (forwards commands via UART to external bus)
//
// Demo Controls:
//   - KEY[0]: Trigger transaction (press to send)
//   - KEY[1]: Increment data pattern (press to change data)
//   - SW[0]:  Reset (HIGH = reset active)
//   - SW[1]:  Internal slave select (0 = Slave 1, 1 = Slave 2)
//   - SW[2]:  External slave select (0 = Remote Slave 1, 1 = Remote Slave 2)
//   - SW[3]:  Master select (0 = Local Master1 to internal, 1 = Local Master1 to external via Bridge)
//
// Operation Modes:
//   SW[3]=0: Internal Mode - Local Master1 writes to internal Slave1/2 (selected by SW[1])
//   SW[3]=1: External Mode - Local Master1 writes to Bridge Slave3 -> UART -> Remote FPGA
//            The remote slave (1 or 2) is selected by SW[2]
//
// LED Display:
//   - LED[0]:   Transaction active
//   - LED[1]:   Mode (0=Internal, 1=External/Bridge)
//   - LED[7:2]: Data pattern (6 bits)
//
// UART Connections (for inter-FPGA communication):
//   Bridge Master (receives commands from external sender):
//     - GPIO_0_BRIDGE_M_TX: Response TX to external system
//     - GPIO_0_BRIDGE_M_RX: Command RX from external system
//   Bridge Slave (forwards commands to external receiver):
//     - GPIO_0_BRIDGE_S_TX: Command TX to external system
//     - GPIO_0_BRIDGE_S_RX: Response RX from external system
//
// Target Device: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
// Clock Frequency: 50 MHz
//==============================================================================

`timescale 1ns / 1ps

module demo_uart_bridge (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        CLOCK_50,            // 50 MHz clock from DE0-Nano
    
    //--------------------------------------------------------------------------
    // Push Buttons (Active Low)
    //--------------------------------------------------------------------------
    input  wire [1:0]  KEY,                 // KEY[0] = Trigger transaction
                                            // KEY[1] = Increment data pattern
    
    //--------------------------------------------------------------------------
    // DIP Switches
    //--------------------------------------------------------------------------
    input  wire [3:0]  SW,                  // SW[0] = Reset (active high)
                                            // SW[1] = Internal slave (0=S1, 1=S2)
                                            // SW[2] = External slave (0=S1, 1=S2)
                                            // SW[3] = Mode (0=Internal, 1=External/Bridge)
    
    //--------------------------------------------------------------------------
    // LEDs for Status Display
    //--------------------------------------------------------------------------
    output wire [7:0]  LED,                 // LED[0] = Transaction active
                                            // LED[1] = Mode (0=Int, 1=Ext)
                                            // LED[7:2] = Data pattern
    
    //--------------------------------------------------------------------------
    // GPIO for Bus Bridge UART Interface
    //--------------------------------------------------------------------------
    // Bridge Master UART (Master 2 - receives commands from external bus)
    output wire        GPIO_0_BRIDGE_M_TX,  // UART TX to external system (for read responses)
    input  wire        GPIO_0_BRIDGE_M_RX,  // UART RX from external system (commands)
    
    // Bridge Slave UART (Slave 3 - forwards commands to external bus)
    output wire        GPIO_0_BRIDGE_S_TX,  // UART TX to external system (commands)
    input  wire        GPIO_0_BRIDGE_S_RX   // UART RX from external system (read responses)
);

    //==========================================================================
    // Configuration Parameters
    //==========================================================================
    localparam [7:0] INITIAL_DATA_PATTERN = 8'h00;
    localparam [11:0] BASE_MEM_ADDR = 12'h010;
    
    // UART: 50MHz / 9600 = 5208 clocks per bit
    localparam UART_CLOCKS_PER_PULSE = 5208;
    localparam BB_ADDR_WIDTH = 12;
    
    //==========================================================================
    // Bus Parameters
    //==========================================================================
    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 8;
    localparam SLAVE1_MEM_ADDR_WIDTH = 11;  // 2KB
    localparam SLAVE2_MEM_ADDR_WIDTH = 12;  // 4KB
    localparam SLAVE3_MEM_ADDR_WIDTH = 12;  // 4KB
    
    //==========================================================================
    // Internal Signals
    //==========================================================================
    wire clk;
    wire rstn;
    
    // Configuration from switches
    wire        cfg_external_mode;   // 0=Internal, 1=External (via Bridge)
    wire        cfg_int_slave_sel;   // Internal slave: 0=S1, 1=S2
    wire        cfg_ext_slave_sel;   // External slave: 0=S1, 1=S2
    wire [1:0]  cfg_slave_sel;       // Final slave selection for bus
    
    // Button edge detection
    reg [2:0] key0_sync;
    reg [2:0] key1_sync;
    wire key0_pressed;
    wire key1_pressed;
    
    // Switch synchronization
    reg [3:0] sw_sync1, sw_sync2;
    wire [3:0] sw_stable;
    
    // Reset synchronization
    reg [2:0] reset_sync;
    
    // Data pattern register
    reg [7:0] data_pattern;
    
    //==========================================================================
    // Clock and Reset Management
    //==========================================================================
    assign clk = CLOCK_50;
    
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], ~SW[0]};
    end
    assign rstn = reset_sync[2];
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sw_sync1 <= 4'b0000;
            sw_sync2 <= 4'b0000;
        end else begin
            sw_sync1 <= SW;
            sw_sync2 <= sw_sync1;
        end
    end
    assign sw_stable = sw_sync2;
    
    // Decode switch settings
    assign cfg_external_mode = sw_stable[3];     // SW[3]: 0=Internal, 1=External (Bridge)
    assign cfg_int_slave_sel = sw_stable[1];     // SW[1]: Internal slave (0=S1, 1=S2)
    assign cfg_ext_slave_sel = sw_stable[2];     // SW[2]: External slave (0=S1, 1=S2)
    
    // Determine actual slave for bus transaction
    // Internal mode: Use SW[1] to select Slave 1 or 2
    // External mode: Always route to Slave 3 (Bridge Slave)
    assign cfg_slave_sel = cfg_external_mode ? 2'b10 :              // External -> Slave 3 (Bridge)
                           (cfg_int_slave_sel ? 2'b01 : 2'b00);     // Internal -> S1 or S2
    
    // Button edge detection
    always @(posedge clk or negedge rstn) begin
        if (!rstn) key0_sync <= 3'b111;
        else key0_sync <= {key0_sync[1:0], KEY[0]};
    end
    assign key0_pressed = (key0_sync[2:1] == 2'b10);
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) key1_sync <= 3'b111;
        else key1_sync <= {key1_sync[1:0], KEY[1]};
    end
    assign key1_pressed = (key1_sync[2:1] == 2'b10);
    
    // Data pattern - increments when KEY[1] is pressed
    always @(posedge clk or negedge rstn) begin
        if (!rstn) data_pattern <= INITIAL_DATA_PATTERN;
        else if (key1_pressed) data_pattern <= data_pattern + 8'h01;
    end
    
    //==========================================================================
    // Demo Transaction Controller FSM
    //==========================================================================
    localparam DEMO_IDLE      = 3'd0;
    localparam DEMO_START     = 3'd1;
    localparam DEMO_WAIT      = 3'd2;
    localparam DEMO_COMPLETE  = 3'd3;
    localparam DEMO_DISPLAY   = 3'd4;
    
    reg [2:0] demo_state;
    reg [19:0] demo_counter;
    reg [7:0] display_data;
    reg transaction_active;
    reg captured_external_mode;
    reg captured_ext_slave_sel;
    
    // Master 1 device interface signals (local Master 1)
    reg [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg [ADDR_WIDTH-1:0] m1_daddr;
    reg m1_dvalid;
    wire m1_dready;
    reg m1_dmode;
    
    // Build full address: {device_addr[3:0], mem_addr[11:0]}
    // Slave 1 = 4'b0000, Slave 2 = 4'b0001, Slave 3 = 4'b0010
    // For external mode, we embed the remote slave selection in the address
    // that will be sent over UART to the remote FPGA
    wire [15:0] full_address;
    wire [11:0] bridge_remote_addr;
    
    // When external: encode remote slave in address sent to bridge
    // Remote Slave 1 = address 0x0xxx, Remote Slave 2 = address 0x1xxx
    assign bridge_remote_addr = {cfg_ext_slave_sel, 1'b0, BASE_MEM_ADDR[9:0]};
    
    // Full address for bus transaction
    assign full_address = cfg_external_mode ? 
                          {2'b00, 2'b10, bridge_remote_addr} :   // External: Slave 3 with remote addr
                          {2'b00, cfg_slave_sel, BASE_MEM_ADDR}; // Internal: Slave 1 or 2
    
    // Demo FSM - Controls Master 1 for local transactions
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            demo_state <= DEMO_IDLE;
            demo_counter <= 20'd0;
            display_data <= 8'h00;
            transaction_active <= 1'b0;
            captured_external_mode <= 1'b0;
            captured_ext_slave_sel <= 1'b0;
            
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dvalid <= 1'b0;
            m1_dmode <= 1'b1;  // Always write mode for demo
        end else begin
            // Default: deassert valid
            m1_dvalid <= 1'b0;
            
            case (demo_state)
                DEMO_IDLE: begin
                    transaction_active <= 1'b0;
                    if (key0_pressed) begin
                        demo_state <= DEMO_START;
                        demo_counter <= 20'd0;
                        // Capture settings at transaction start
                        captured_external_mode <= cfg_external_mode;
                        captured_ext_slave_sel <= cfg_ext_slave_sel;
                    end
                end
                
                DEMO_START: begin
                    transaction_active <= 1'b1;
                    m1_daddr <= full_address;
                    m1_dwdata <= data_pattern;
                    m1_dmode <= 1'b1;  // Write mode
                    m1_dvalid <= 1'b1;
                    demo_state <= DEMO_WAIT;
                    demo_counter <= 20'd0;
                end
                
                DEMO_WAIT: begin
                    demo_counter <= demo_counter + 1'b1;
                    
                    // Extended timeout for UART bridge transactions (~10ms for 9600 baud)
                    if (m1_dready || (demo_counter > 20'd500000)) begin
                        demo_state <= DEMO_COMPLETE;
                    end
                end
                
                DEMO_COMPLETE: begin
                    display_data <= data_pattern;
                    demo_state <= DEMO_DISPLAY;
                    demo_counter <= 20'd0;
                end
                
                DEMO_DISPLAY: begin
                    transaction_active <= 1'b0;
                    demo_state <= DEMO_IDLE;
                end
                
                default: demo_state <= DEMO_IDLE;
            endcase
        end
    end
    
    //==========================================================================
    // LED Display Assignment
    //==========================================================================
    // LED[0] = Transaction active
    // LED[1] = Mode (0=Internal, 1=External/Bridge)
    // LED[7:2] = Data pattern (6 bits)
    assign LED[0] = transaction_active;
    assign LED[1] = cfg_external_mode;
    assign LED[7:2] = display_data[5:0];
    
    //==========================================================================
    // Internal Bus Signals
    //==========================================================================
    // Master 1 to Bus (local master)
    wire m1_rdata, m1_wdata, m1_mode, m1_mvalid, m1_svalid;
    wire m1_breq, m1_bgrant, m1_ack, m1_split;
    
    // Master 2 to Bus (Bus Bridge Master - receives external commands)
    wire m2_rdata, m2_wdata, m2_mode, m2_mvalid, m2_svalid;
    wire m2_breq, m2_bgrant, m2_ack, m2_split;
    
    // Slave interface signals
    wire s1_rdata, s1_wdata, s1_mode, s1_mvalid, s1_svalid, s1_ready;
    wire s2_rdata, s2_wdata, s2_mode, s2_mvalid, s2_svalid, s2_ready;
    wire s3_rdata, s3_wdata, s3_mode, s3_mvalid, s3_svalid, s3_ready;
    wire s3_split;
    wire split_grant;
    
    //==========================================================================
    // Master Port 1 - Used for local transactions
    //==========================================================================
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
    
    //==========================================================================
    // Master 2 - Bus Bridge Master
    // Receives UART commands from external system and executes on local bus
    // Connected to GPIO_0_BRIDGE_M_TX/RX
    //==========================================================================
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
        .u_tx(GPIO_0_BRIDGE_M_TX),   // TX for read responses to external
        .u_rx(GPIO_0_BRIDGE_M_RX)    // RX commands from external
    );
    
    //==========================================================================
    // Bus Interconnect
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
    // Slave 1 - Local Memory (2KB)
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
    // Slave 2 - Local Memory (4KB)
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
    // Slave 3 - Bus Bridge Slave
    // Forwards local bus commands via UART to external system
    // Connected to GPIO_0_BRIDGE_S_TX/RX
    //==========================================================================
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
        .u_tx(GPIO_0_BRIDGE_S_TX),   // TX commands to external
        .u_rx(GPIO_0_BRIDGE_S_RX)    // RX read responses from external
    );

endmodule
