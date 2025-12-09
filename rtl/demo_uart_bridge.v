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
//   - KEY[0]: Initiate transfer (press to execute read or write)
//   - KEY[1]: Increment value (data in write mode, address in read mode)
//   - KEY[0]+KEY[1]: Press both together to reset both counters to 0
//   - SW[0]:  Reset (HIGH = reset active)
//   - SW[1]:  Slave select (0 = Slave 1, 1 = Slave 2) for both internal/external
//   - SW[2]:  Mode select (0 = Internal, 1 = External via Bridge)
//   - SW[3]:  Read/Write (0 = Read, 1 = Write)
//
// Operation Modes:
//   SW[2]=0: Internal Mode - Access local Slave1/2 (selected by SW[1])
//   SW[2]=1: External Mode - Access remote Slave1/2 via Bridge (selected by SW[1])
//
// LED Display:
//   - Write mode (SW[3]=1): LED[7:0] = Data value to write
//   - Read mode  (SW[3]=0): LED[7:0] = Data read from slave
//
// Address/Data Behavior:
//   Two separate counters: data_pattern (for write data) and addr_offset (for address)
//   
//   WRITE MODE (SW[3]=1):
//     - KEY[1]: Increment data value (shown on LED)
//     - KEY[0]: Write data to current address, then auto-increment address
//     - Allows sequential writes: set data, write, set new data, write...
//   
//   READ MODE (SW[3]=0):
//     - KEY[1]: Increment address offset
//     - KEY[0]: Read from current address (result shown on LED)
//     - Allows reading any address: select address with KEY[1], read with KEY[0]
//   
//   RESET (KEY[0]+KEY[1] together): Reset both counters to 0
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
    input  wire [1:0]  KEY,                 // KEY[0] = Initiate transfer
                                            // KEY[1] = Increment data value
                                            // Both pressed = Reset increment to 0
    
    //--------------------------------------------------------------------------
    // DIP Switches
    //--------------------------------------------------------------------------
    input  wire [3:0]  SW,                  // SW[0] = Reset (active high)
                                            // SW[1] = Slave select (0=S1, 1=S2)
                                            // SW[2] = Mode (0=Internal, 1=External)
                                            // SW[3] = R/W (0=Read, 1=Write)
    
    //--------------------------------------------------------------------------
    // LEDs for Status Display
    //--------------------------------------------------------------------------
    output wire [7:0]  LED,                 // Write mode: increment value
                                            // Read mode: data from slave
    
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
    wire        cfg_slave_sel;       // Slave select: 0=S1, 1=S2
    wire        cfg_external_mode;   // 0=Internal, 1=External (via Bridge)
    wire        cfg_write_mode;      // 0=Read, 1=Write
    wire [1:0]  bus_slave_sel;       // Final slave selection for bus
    
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
    wire both_keys_pressed;          // Both keys pressed together
    reg both_keys_held;              // Track if both were held
    
    // Switch synchronization
    reg [3:0] sw_sync1, sw_sync2;
    wire [3:0] sw_stable;
    
    // Reset synchronization
    reg [2:0] reset_sync;
    
    // Data pattern register (increment value)
    reg [7:0] data_pattern;
    
    // Read data storage
    reg [7:0] read_data;
    
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
    assign cfg_slave_sel     = sw_stable[1];     // SW[1]: Slave select (0=S1, 1=S2)
    assign cfg_external_mode = sw_stable[2];     // SW[2]: 0=Internal, 1=External (Bridge)
    assign cfg_write_mode    = sw_stable[3];     // SW[3]: 0=Read, 1=Write
    
    // Determine actual slave for bus transaction
    // Internal mode: Use SW[1] to select Slave 1 or 2
    // External mode: Always route to Slave 3 (Bridge Slave)
    assign bus_slave_sel = cfg_external_mode ? 2'b10 :              // External -> Slave 3 (Bridge)
                           (cfg_slave_sel ? 2'b01 : 2'b00);         // Internal -> S1 or S2
    
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
            both_keys_held <= 1'b0;
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
            
            // Track if both keys are currently held (active low)
            if (!key0_stable && !key1_stable)
                both_keys_held <= 1'b1;
            else if (key0_stable && key1_stable)
                both_keys_held <= 1'b0;
        end
    end
    
    // Both keys pressed together detection
    // Detect when both keys become pressed - needs to handle simultaneous press
    // Use a registered version of both_keys_held for proper timing
    reg both_keys_held_d;
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            both_keys_held_d <= 1'b0;
        else
            both_keys_held_d <= both_keys_held;
    end
    
    // Rising edge of both_keys_held means both keys just became pressed together
    assign both_keys_pressed = both_keys_held && !both_keys_held_d;
    
    // Single key press detection (falling edge on debounced signal, only if other key not held)
    // Active low: pressed = 0, so falling edge (1->0) = press
    assign key0_pressed = (key0_stable_d && !key0_stable) && key1_stable;  // KEY[0] pressed, KEY[1] not held
    assign key1_pressed = (key1_stable_d && !key1_stable) && key0_stable;  // KEY[1] pressed, KEY[0] not held
    
    // Separate counters for data and address
    // - data_pattern: value to write (incremented by KEY[1] in write mode)
    // - addr_offset:  address offset (incremented by KEY[1] in read mode, auto-increments after write)
    reg [7:0] addr_offset;
    
    // Data pattern management (for write mode):
    // - KEY[1] in write mode: increment data value
    // - KEY[0]+KEY[1] together: reset both counters to 0
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_pattern <= INITIAL_DATA_PATTERN;
        end else if (both_keys_pressed) begin
            data_pattern <= 8'h00;  // Both keys pressed resets to 0
        end else if (key1_pressed && cfg_write_mode) begin
            data_pattern <= data_pattern + 8'h01;  // KEY[1] in write mode increments data
        end
    end
    
    //==========================================================================
    // Demo Transaction Controller FSM - State definitions (declared early for use below)
    //==========================================================================
    localparam DEMO_IDLE       = 3'd0;
    localparam DEMO_START      = 3'd1;
    localparam DEMO_WAIT_START = 3'd2;
    localparam DEMO_WAIT       = 3'd3;
    localparam DEMO_COMPLETE   = 3'd4;
    localparam DEMO_DISPLAY    = 3'd5;
    
    reg [2:0] demo_state;
    reg [19:0] demo_counter;
    reg transaction_active;
    reg captured_write_mode;         // Captured R/W mode at transaction start
    
    // Address offset management (for read mode):
    // - KEY[1] in read mode: increment address offset
    // - KEY[0]+KEY[1] together: reset both counters to 0
    // - After successful write: auto-increment address
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            addr_offset <= 8'h00;
        end else if (both_keys_pressed) begin
            addr_offset <= 8'h00;  // Both keys pressed resets to 0
        end else if (key1_pressed && !cfg_write_mode) begin
            addr_offset <= addr_offset + 8'h01;  // KEY[1] in read mode increments address
        end else if (demo_state == DEMO_COMPLETE && captured_write_mode) begin
            addr_offset <= addr_offset + 8'h01;  // Auto-increment after write completes
        end
    end
    
    //==========================================================================
    // Master 1 Device Interface Signals
    //==========================================================================
    // Master 1 device interface signals (local Master 1)
    reg [DATA_WIDTH-1:0] m1_dwdata;
    wire [DATA_WIDTH-1:0] m1_drdata;
    reg [ADDR_WIDTH-1:0] m1_daddr;
    reg m1_dvalid;
    wire m1_dready;
    reg m1_dmode;
    
    //==========================================================================
    // Address Generation
    //==========================================================================
    // Build full address: {device_addr[3:0], mem_addr[11:0]}
    // Slave 1 = 4'b0000, Slave 2 = 4'b0001, Slave 3 = 4'b0010
    // For external mode, we embed the remote slave selection in the address
    // that will be sent over UART to the remote FPGA
    wire [15:0] full_address;
    wire [11:0] mem_address;
    wire [11:0] bridge_remote_addr;
    
    // Memory address uses addr_offset (which is separate from data_pattern)
    assign mem_address = BASE_MEM_ADDR + {4'b0000, addr_offset};
    
    // When external: encode remote slave in address sent to bridge
    // MSB (bit 11) must be 1 for bridge access (vs local memory)
    // Bit 10 selects remote slave: 0=Slave1, 1=Slave2
    // Bits 9:0 are the memory address within the remote slave
    // Remote Slave 1 = address 0x8xxx, Remote Slave 2 = address 0xCxxx
    assign bridge_remote_addr = {1'b1, cfg_slave_sel, mem_address[9:0]};
    
    // Full address for bus transaction
    assign full_address = cfg_external_mode ? 
                          {2'b00, 2'b10, bridge_remote_addr} :   // External: Slave 3 with remote addr
                          {2'b00, bus_slave_sel, mem_address};   // Internal: Slave 1 or 2
    
    //==========================================================================
    // Demo Transaction Controller FSM
    //==========================================================================
    // Demo FSM - Controls Master 1 for local transactions (read or write)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            demo_state <= DEMO_IDLE;
            demo_counter <= 20'd0;
            read_data <= 8'h00;
            transaction_active <= 1'b0;
            captured_write_mode <= 1'b0;
            
            m1_dwdata <= 8'h00;
            m1_daddr <= 16'h0000;
            m1_dvalid <= 1'b0;
            m1_dmode <= 1'b1;
        end else begin
            // Default: deassert valid
            m1_dvalid <= 1'b0;
            
            case (demo_state)
                DEMO_IDLE: begin
                    transaction_active <= 1'b0;
                    if (key0_pressed) begin
                        demo_state <= DEMO_START;
                        demo_counter <= 20'd0;
                        // Capture R/W mode at transaction start
                        captured_write_mode <= cfg_write_mode;
                    end
                end
                
                DEMO_START: begin
                    transaction_active <= 1'b1;
                    m1_daddr <= full_address;
                    m1_dwdata <= data_pattern;
                    m1_dmode <= captured_write_mode;  // 0=Read, 1=Write from SW[3]
                    m1_dvalid <= 1'b1;
                    demo_state <= DEMO_WAIT_START;
                    demo_counter <= 20'd0;
                end
                
                DEMO_WAIT_START: begin
                    // Wait for master to leave IDLE (start the transaction)
                    // Keep dvalid asserted until master acknowledges
                    m1_dvalid <= 1'b1;
                    if (!m1_dready) begin
                        // Master has started - now wait for completion
                        demo_state <= DEMO_WAIT;
                        m1_dvalid <= 1'b0;
                    end
                    demo_counter <= demo_counter + 1'b1;
                    // Timeout if master doesn't start
                    if (demo_counter > 20'd1000) begin
                        demo_state <= DEMO_COMPLETE;
                        m1_dvalid <= 1'b0;
                    end
                end
                
                DEMO_WAIT: begin
                    demo_counter <= demo_counter + 1'b1;
                    
                    // Extended timeout for UART bridge transactions (~10ms for 9600 baud)
                    if (m1_dready || (demo_counter > 20'd500000)) begin
                        demo_state <= DEMO_COMPLETE;
                    end
                end
                
                DEMO_COMPLETE: begin
                    // Capture read data if this was a read operation
                    if (!captured_write_mode) begin
                        read_data <= m1_drdata;
                    end
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
    // Write mode (SW[3]=1): LED[7:0] = increment value (data to write)
    // Read mode  (SW[3]=0): LED[7:0] = data read from slave
    assign LED = cfg_write_mode ? data_pattern : read_data;
    
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
