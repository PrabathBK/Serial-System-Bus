//==============================================================================
// File: demo_uart_bridge.v
// Description: Priority Demonstration Wrapper for ADS Bus System
//              Demonstrates Master 1 priority over Master 2 by triggering
//              simultaneous transactions to the same fixed address.
//
// Target: DE0-Nano FPGA
// 
// Architecture:
//   Master 1: Local master (higher priority) - WRITE operations
//   Master 2: Local master (lower priority) - READ operations
//   Slave 1:  Local memory (2KB) - Shared target
//   Slave 2:  Local memory (4KB)
//   Slave 3:  Bus Bridge Slave (forwards commands via UART to external bus)
//
// Demo Controls (Priority Demo Mode):
//   - KEY[0]: Simultaneously trigger BOTH Master 1 (write) and Master 2 (read)
//             to the same fixed address to demonstrate priority arbitration
//   - KEY[1]: Increment data value that Master 1 will write
//   - SW[0]:  Reset (HIGH = reset active)
//
// Fixed Address Demo:
//   - Both masters target address 0x0020 in Slave 1
//   - Master 1: WRITE operation (higher priority - should win arbitration)
//   - Master 2: READ operation (lower priority - should wait)
//
// LED Display:
//   - LED[7:4]: Current data value (Master 1 will write this)
//   - LED[3]:   Master 1 transaction active
//   - LED[2]:   Master 2 transaction active
//   - LED[1]:   Master 1 has bus grant (shows priority)
//   - LED[0]:   Master 2 has bus grant
//
// Operation:
//   Press KEY[0] to trigger both masters simultaneously. The LEDs will show:
//   1. Both LED[3] and LED[2] turn on (both requesting)
//   2. LED[1] turns on first (Master 1 gets priority)
//   3. LED[0] turns on after (Master 2 gets bus after Master 1 completes)
//   This demonstrates the arbiter giving priority to Master 1
//
// Target Device: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
// Clock Frequency: 50 MHz
//==============================================================================

`timescale 1ns / 1ps

module demo_uart_bridge #(
    // Debounce parameter - set to small value for simulation, large for hardware
    parameter DEBOUNCE_COUNT = 50000   // ~1ms at 50MHz for real hardware
) (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        CLOCK_50,            // 50 MHz clock from DE0-Nano
    
    //--------------------------------------------------------------------------
    // Push Buttons (Active Low)
    //--------------------------------------------------------------------------
    input  wire [1:0]  KEY,                 // KEY[0] = Trigger both masters simultaneously
                                            // KEY[1] = Increment data value
    
    //--------------------------------------------------------------------------
    // DIP Switches
    //--------------------------------------------------------------------------
    input  wire [3:0]  SW,                  // SW[0] = Reset (active high)
                                            // SW[1:3] = Unused in priority demo mode
    
    //--------------------------------------------------------------------------
    // LEDs for Status Display
    //--------------------------------------------------------------------------
    output wire [7:0]  LED,                 // LED[7:4] = Data value to write
                                            // LED[3]   = Master 1 active
                                            // LED[2]   = Master 2 active
                                            // LED[1]   = Master 1 has bus grant
                                            // LED[0]   = Master 2 has bus grant
    
    //--------------------------------------------------------------------------
    // GPIO for Bus Bridge UART Interface (unused in priority demo mode)
    //--------------------------------------------------------------------------
    output wire        GPIO_0_BRIDGE_M_TX,  // Unused in priority demo
    input  wire        GPIO_0_BRIDGE_M_RX,  // Unused in priority demo
    
    output wire        GPIO_0_BRIDGE_S_TX,  // UART TX to external system (commands)
    input  wire        GPIO_0_BRIDGE_S_RX   // UART RX from external system (read responses)
);

    //==========================================================================
    // Tie off unused UART TX (Master 2 no longer uses UART in priority demo)
    //==========================================================================
    assign GPIO_0_BRIDGE_M_TX = 1'b1;  // Idle high for UART

    //==========================================================================
    // Configuration Parameters
    //==========================================================================
    localparam [7:0] INITIAL_DATA_PATTERN = 8'h00;
    
    // Fixed shared address for priority demonstration
    // Both masters will target this address: Slave 1, address 0x0020
    localparam [15:0] FIXED_DEMO_ADDR = 16'h0020;  // Device 0 (Slave 1), mem addr 0x020
    
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
    
    // Button debouncing and edge detection
    reg [2:0] key0_sync;
    reg [2:0] key1_sync;
    reg [15:0] key0_debounce;        // Debounce counter for KEY[0]
    reg [15:0] key1_debounce;        // Debounce counter for KEY[1]
    reg key0_stable;                 // Debounced KEY[0] state
    reg key1_stable;                 // Debounced KEY[1] state
    reg key0_stable_d;               // Delayed for edge detection
    reg key1_stable_d;               // Delayed for edge detection
    wire key0_pressed;               // KEY[0] press detected (debounced)
    wire key1_pressed;               // KEY[1] press detected (debounced)
    
    // Reset synchronization
    reg [2:0] reset_sync;
    
    // Data pattern register (value to write)
    reg [7:0] data_pattern;
    
    //==========================================================================
    // Clock and Reset Management
    //==========================================================================
    assign clk = CLOCK_50;
    
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], ~SW[0]};
    end
    assign rstn = reset_sync[2];
    
    // Button synchronization and debouncing
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            key0_sync <= 3'b111;
            key1_sync <= 3'b111;
            key0_debounce <= 16'd0;
            key1_debounce <= 16'd0;
            key0_stable <= 1'b1;
            key1_stable <= 1'b1;
            key0_stable_d <= 1'b1;
            key1_stable_d <= 1'b1;
        end else begin
            // Synchronize raw key inputs
            key0_sync <= {key0_sync[1:0], KEY[0]};
            key1_sync <= {key1_sync[1:0], KEY[1]};
            
            // Debounce KEY[0]
            if (key0_sync[2] != key0_stable) begin
                // Key state changed, start debounce counter
                if (key0_debounce < DEBOUNCE_COUNT) begin
                    key0_debounce <= key0_debounce + 1'b1;
                end else begin
                    // Debounce time passed, accept new state
                    key0_stable <= key0_sync[2];
                    key0_debounce <= 16'd0;
                end
            end else begin
                key0_debounce <= 16'd0;
            end
            
            // Debounce KEY[1]
            if (key1_sync[2] != key1_stable) begin
                if (key1_debounce < DEBOUNCE_COUNT) begin
                    key1_debounce <= key1_debounce + 1'b1;
                end else begin
                    key1_stable <= key1_sync[2];
                    key1_debounce <= 16'd0;
                end
            end else begin
                key1_debounce <= 16'd0;
            end
            
            // Edge detection delay registers
            key0_stable_d <= key0_stable;
            key1_stable_d <= key1_stable;
        end
    end
    
    // Key press detection (falling edge on debounced signal)
    // Active low: pressed = 0, so falling edge (1->0) = press
    assign key0_pressed = (key0_stable_d && !key0_stable);  // KEY[0] pressed
    assign key1_pressed = (key1_stable_d && !key1_stable);  // KEY[1] pressed
    
    // Data pattern management - value that Master 1 will write
    // KEY[1]: increment data value
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_pattern <= INITIAL_DATA_PATTERN;
        end else if (key1_pressed) begin
            data_pattern <= data_pattern + 8'h01;  // KEY[1] increments data
        end
    end
    
    //==========================================================================
    // Master Controllers FSM - State definitions
    //==========================================================================
    localparam IDLE       = 2'd0;
    localparam START      = 2'd1;
    localparam WAIT       = 2'd2;
    localparam COMPLETE   = 2'd3;
    
    // Master 1 FSM state and control
    reg [1:0] m1_state;
    reg [19:0] m1_counter;
    reg m1_active;              // Master 1 transaction active
    
    // Master 2 FSM state and control  
    reg [1:0] m2_state;
    reg [19:0] m2_counter;
    reg m2_active;              // Master 2 transaction active
    
    //==========================================================================
    // Master 1 Device Interface Signals
    //==========================================================================
    reg [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg [ADDR_WIDTH-1:0] m1_daddr;
    reg m1_dvalid;
    wire m1_dready;
    reg m1_dmode;
    
    //==========================================================================
    // Master 2 Device Interface Signals (for local control, not UART)
    //==========================================================================
    reg [DATA_WIDTH-1:0] m2_dwdata;
    wire [DATA_WIDTH-1:0] m2_drdata;
    reg [ADDR_WIDTH-1:0] m2_daddr;
    reg m2_dvalid;
    wire m2_dready;
    reg m2_dmode;
    
    //==========================================================================
    // Master 1 Transaction Controller FSM
    // Master 1 performs WRITE operations
    //==========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            m1_state <= IDLE;
            m1_counter <= 20'd0;
            m1_active <= 1'b0;
            
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dvalid <= 1'b0;
            m1_dmode <= 1'b1;  // Always WRITE
        end else begin
            // Default: deassert valid
            m1_dvalid <= 1'b0;
            
            case (m1_state)
                IDLE: begin
                    m1_active <= 1'b0;
                    if (key0_pressed) begin
                        m1_state <= START;
                        m1_counter <= 20'd0;
                    end
                end
                
                START: begin
                    m1_active <= 1'b1;
                    m1_daddr <= FIXED_DEMO_ADDR;      // Fixed address
                    m1_dwdata <= data_pattern;         // Write current data value
                    m1_dmode <= 1'b1;                  // WRITE mode
                    m1_dvalid <= 1'b1;
                    
                    if (!m1_dready) begin
                        // Master has started transaction
                        m1_state <= WAIT;
                        m1_dvalid <= 1'b0;
                    end
                    
                    m1_counter <= m1_counter + 1'b1;
                    // Timeout if master doesn't start
                    if (m1_counter > 20'd1000) begin
                        m1_state <= COMPLETE;
                        m1_dvalid <= 1'b0;
                    end
                end
                
                WAIT: begin
                    m1_counter <= m1_counter + 1'b1;
                    
                    // Wait for completion or timeout
                    if (m1_dready || (m1_counter > 20'd100000)) begin
                        m1_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    m1_active <= 1'b0;
                    m1_state <= IDLE;
                    m1_counter <= 20'd0;
                end
                
                default: m1_state <= IDLE;
            endcase
        end
    end
    
    //==========================================================================
    // Master 2 Transaction Controller FSM
    // Master 2 performs READ operations
    //==========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            m2_state <= IDLE;
            m2_counter <= 20'd0;
            m2_active <= 1'b0;
            
            m2_dwdata <= 8'h00;
            m2_daddr <= 16'h0000;
            m2_dvalid <= 1'b0;
            m2_dmode <= 1'b0;  // Always READ
        end else begin
            // Default: deassert valid
            m2_dvalid <= 1'b0;
            
            case (m2_state)
                IDLE: begin
                    m2_active <= 1'b0;
                    if (key0_pressed) begin
                        m2_state <= START;
                        m2_counter <= 20'd0;
                    end
                end
                
                START: begin
                    m2_active <= 1'b1;
                    m2_daddr <= FIXED_DEMO_ADDR;      // Same fixed address as M1
                    m2_dwdata <= 8'h00;                // Don't care for read
                    m2_dmode <= 1'b0;                  // READ mode
                    m2_dvalid <= 1'b1;
                    
                    if (!m2_dready) begin
                        // Master has started transaction
                        m2_state <= WAIT;
                        m2_dvalid <= 1'b0;
                    end
                    
                    m2_counter <= m2_counter + 1'b1;
                    // Timeout if master doesn't start
                    if (m2_counter > 20'd1000) begin
                        m2_state <= COMPLETE;
                        m2_dvalid <= 1'b0;
                    end
                end
                
                WAIT: begin
                    m2_counter <= m2_counter + 1'b1;
                    
                    // Wait for completion or timeout
                    if (m2_dready || (m2_counter > 20'd100000)) begin
                        m2_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    m2_active <= 1'b0;
                    m2_state <= IDLE;
                    m2_counter <= 20'd0;
                end
                
                default: m2_state <= IDLE;
            endcase
        end
    end
    
    //==========================================================================
    // LED Display Assignment
    //==========================================================================
    // LED[7:4]: Current data value (Master 1 will write this)
    // LED[3]:   Master 1 transaction active
    // LED[2]:   Master 2 transaction active
    // LED[1]:   Master 1 has bus grant
    // LED[0]:   Master 2 has bus grant
    assign LED[7:4] = data_pattern[3:0];
    assign LED[3] = m1_active;
    assign LED[2] = m2_active;
    assign LED[1] = m1_bgrant;
    assign LED[0] = m2_bgrant;
    
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
    // Master Port 1 - Local master (higher priority)
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
    // Master Port 2 - Local master (lower priority)
    //==========================================================================
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE3_MEM_ADDR_WIDTH)
    ) master2_port (
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
