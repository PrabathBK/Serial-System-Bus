//==============================================================================
// File: bus_bridge_slave.v
// Description: Bus Bridge Slave module with local memory and UART bridge
//              
//              This module acts as a slave on the local bus and can:
//              1. Store data in local BRAM (internal transactions)
//              2. Forward transactions via UART to a remote system (bridge mode)
//
// Address Space:
//   - Lower addresses: Local BRAM storage
//   - Upper addresses (MSB=1): Forward via UART to remote system
//
// Architecture:
//   +-----------------------------------------------------------+
//   |                   bus_bridge_slave.v                      |
//   |  +--------------+   +-------------+   +----------------+  |
//   |  | slave_port   |---|  Controller |---| slave_memory   |  |
//   |  | (bus proto)  |   |   (FSM)     |   |    _bram       |  |
//   |  +--------------+   +-------------+   | (local store)  |  |
//   |         |                 |           +----------------+  |
//   |         |                 |                               |
//   |         |           +----------+                          |
//   |         |           |   UART   |----- TX/RX to remote     |
//   |         |           +----------+                          |
//   +---------|------------------------------------------+-----+
//             |                                          |
//         from/to local bus                          UART lines
//
//==============================================================================
// Author: ADS Bus System
// Date: 2025-12-02
//==============================================================================

`timescale 1ns / 1ps

module bus_bridge_slave #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,
    parameter UART_CLOCKS_PER_PULSE = 5208,
    parameter LOCAL_MEM_SIZE = 2048,       // Local memory size (half of address space)
    parameter BRIDGE_ENABLE = 1,           // Enable UART bridge functionality
    parameter ENABLE_ADAPTERS = 0          // Enable protocol adapters for other team's system
)(
    input clk, rstn,
    
    //--------------------------------------------------------------------------
    // Serial Bus Interface (connecting to local bus)
    //--------------------------------------------------------------------------
    input  wire swdata,        // Write data and address from master
    input  wire smode,         // 0 - read, 1 - write, from master
    input  wire mvalid,        // wdata valid (receiving data and address from master)
    input  wire split_grant,   // Grant bus access in split
    
    output wire srdata,        // Read data to the master
    output wire svalid,        // rdata valid (sending data from slave)
    output wire sready,        // Slave is ready for transaction
    output wire ssplit,        // Split signal
    
    //--------------------------------------------------------------------------
    // Bus Bridge UART Interface (connecting to remote system)
    //--------------------------------------------------------------------------
    output wire u_tx,          // UART transmit to remote
    input  wire u_rx           // UART receive from remote
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam UART_TX_DATA_WIDTH = DATA_WIDTH + ADDR_WIDTH + 1;    // Transmit: mode + data + addr
    localparam UART_RX_DATA_WIDTH = DATA_WIDTH;                     // Receive: only read data
    localparam SPLIT_EN = 1'b1;  // Enable split for UART operations (they take time)
    
    // Address bit to distinguish local vs bridge operation
    // MSB of address: 0 = local memory, 1 = bridge to remote
    localparam LOCAL_ADDR_MSB = ADDR_WIDTH - 1;

    //--------------------------------------------------------------------------
    // Internal Signals - Slave Port to Controller
    //--------------------------------------------------------------------------
    wire [DATA_WIDTH-1:0]    sp_memrdata;    // Data read from memory
    wire                     sp_memwen;      // Write enable from slave port
    wire                     sp_memren;      // Read enable from slave port
    wire [ADDR_WIDTH-1:0]    sp_memaddr;     // Address from slave port
    wire [DATA_WIDTH-1:0]    sp_memwdata;    // Write data from slave port
    reg                      sp_rvalid;      // Read valid to slave port
    wire                     sp_ready;       // Slave port ready
    
    //--------------------------------------------------------------------------
    // Internal Signals - Local Memory
    //--------------------------------------------------------------------------
    wire                     lmem_wen;       // Local memory write enable
    wire                     lmem_ren;       // Local memory read enable
    wire [ADDR_WIDTH-2:0]    lmem_addr;      // Local memory address (one bit less)
    wire [DATA_WIDTH-1:0]    lmem_rdata;     // Local memory read data
    wire                     lmem_rvalid;    // Local memory read valid

    //--------------------------------------------------------------------------
    // Internal Signals - UART (Direct mode - no adapters)
    //--------------------------------------------------------------------------
    reg  [UART_TX_DATA_WIDTH-1:0] u_din;     // UART transmit data (21-bit frame)
    reg                           u_en;       // UART transmit enable
    wire                          u_tx_busy;  // UART transmitter busy (direct)
    wire                          u_rx_ready; // UART receive data ready
    wire [UART_RX_DATA_WIDTH-1:0] u_dout;    // UART receive data
    wire                          u_tx_internal; // Internal UART TX (before adapter)
    
    //--------------------------------------------------------------------------
    // Internal Signals - TX Adapter (for other team's protocol)
    //--------------------------------------------------------------------------
    wire [20:0] tx_adapter_frame_in;         // Frame to TX adapter
    wire        tx_adapter_frame_valid;      // Frame valid signal
    wire        tx_adapter_frame_ready;      // Adapter ready for frame
    wire [7:0]  tx_adapter_uart_data;        // Data from adapter to their UART
    wire        tx_adapter_uart_wr_en;       // Write enable from adapter
    wire        tx_adapter_uart_busy;        // UART busy (via adapter)

    //--------------------------------------------------------------------------
    // Internal Signals - Controller
    //--------------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0] latched_rdata;     // Latched read data from UART
    reg  [DATA_WIDTH-1:0] latched_wdata;     // Latched write data from slave_port
    reg  [ADDR_WIDTH-1:0] latched_addr;      // Latched address from slave_port
    reg                   rdata_received;    // Flag: UART data received
    reg                   prev_u_rx_ready;   // Previous UART ready state
    reg                   pending_write;     // Flag: write pending for UART TX
    reg                   pending_read;      // Flag: read pending for UART TX
    wire                  is_bridge_access;  // Address indicates bridge access
    wire                  is_local_access;   // Address indicates local memory access

    //--------------------------------------------------------------------------
    // Address Decode Logic (using latched address for FSM decisions)
    //--------------------------------------------------------------------------
    wire is_bridge_access_now = sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE;
    wire is_local_access_now  = ~sp_memaddr[LOCAL_ADDR_MSB];
    
    assign is_bridge_access = latched_addr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE;
    assign is_local_access  = ~latched_addr[LOCAL_ADDR_MSB];
    
    // Local memory signals
    assign lmem_wen  = sp_memwen & is_local_access;
    assign lmem_ren  = sp_memren & is_local_access;
    assign lmem_addr = sp_memaddr[ADDR_WIDTH-2:0];

    //--------------------------------------------------------------------------
    // Slave Port Instantiation
    // NOTE: sp_split_grant is defined later after state declaration
    //       sp_ssplit is internal; we extend ssplit for bridge operations
    //--------------------------------------------------------------------------
    wire sp_split_grant;  // Forward declaration - assigned after state declared
    wire sp_ssplit;       // Internal ssplit from slave_port
    
    slave_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(SPLIT_EN)
    ) slave (
        .clk(clk), 
        .rstn(rstn),
        .smemrdata(sp_memrdata),
        .rvalid(sp_rvalid),
        .smemwen(sp_memwen), 
        .smemren(sp_memren),
        .smemaddr(sp_memaddr), 
        .smemwdata(sp_memwdata),
        .swdata(swdata),
        .srdata(srdata),
        .smode(smode),
        .mvalid(mvalid),	
        .split_grant(sp_split_grant),
        .svalid(svalid),	
        .sready(sp_ready),
        .ssplit(sp_ssplit)
    );

    //--------------------------------------------------------------------------
    // Local Memory BRAM Instantiation
    //--------------------------------------------------------------------------
    slave_memory_bram #(
        .ADDR_WIDTH(ADDR_WIDTH-1),  // One bit less for local addressing
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_SIZE(LOCAL_MEM_SIZE)
    ) local_mem (
        .clk(clk),
        .rstn(rstn),
        .wen(lmem_wen),
        .ren(lmem_ren),
        .addr(lmem_addr),
        .wdata(sp_memwdata),
        .rdata(lmem_rdata),
        .rvalid(lmem_rvalid)
    );

    //--------------------------------------------------------------------------
    // UART Module Instantiation (for bridge operations - direct mode)
    // This UART is only used when ENABLE_ADAPTERS=0 (direct 21-bit protocol)
    //--------------------------------------------------------------------------
    wire u_tx_busy_direct;  // Direct UART busy
    
    uart #(
        .CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .TX_DATA_WIDTH(UART_TX_DATA_WIDTH),
        .RX_DATA_WIDTH(UART_RX_DATA_WIDTH)
    ) uart_module (
        .data_input(u_din),
        .data_en(u_en),
        .clk(clk),
        .rstn(rstn),
        .tx(u_tx_internal),
        .tx_busy(u_tx_busy_direct),
        .rx(u_rx),  
        .ready(u_rx_ready),   
        .data_output(u_dout)
    );
    
    //--------------------------------------------------------------------------
    // TX Adapter Module (for other team's protocol)
    // Converts 21-bit frames to 4-byte sequence at 115200 baud
    //--------------------------------------------------------------------------
    generate
        if (ENABLE_ADAPTERS == 1) begin : tx_adapter_gen
            // Instantiate TX adapter
            uart_to_other_team_tx_adapter tx_adapter (
                .clk(clk),
                .rstn(rstn),
                .frame_in(tx_adapter_frame_in),
                .frame_valid(tx_adapter_frame_valid),
                .frame_ready(tx_adapter_frame_ready),
                .uart_data_in(tx_adapter_uart_data),
                .uart_wr_en(tx_adapter_uart_wr_en),
                .uart_tx_busy(tx_adapter_uart_busy),
                .clk_50m(clk)
            );
            
            // Instantiate UART TX for adapter (8-bit per byte, 115200 baud)
            uart_tx #(
                .CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),  // Should be 434 for 115200
                .DATA_WIDTH(8)
            ) adapter_uart_tx (
                .data_in(tx_adapter_uart_data),
                .data_en(tx_adapter_uart_wr_en),
                .clk(clk),
                .rstn(rstn),
                .tx(u_tx),
                .tx_busy(tx_adapter_uart_busy)
            );
            
            // Connect frame signals: present u_din and u_en as frame interface
            assign tx_adapter_frame_in = u_din;
            assign tx_adapter_frame_valid = u_en;
            // Map adapter's ready to internal busy (inverted logic)
            // When adapter is ready, we're not busy
            
        end else begin : no_adapter
            // Direct connection without adapter
            assign u_tx = u_tx_internal;
        end
    endgenerate
    
    // Multiplex busy signal based on adapter enable
    assign u_tx_busy = (ENABLE_ADAPTERS == 1) ? !tx_adapter_frame_ready : u_tx_busy_direct;

    //--------------------------------------------------------------------------
    // Controller FSM States
    //--------------------------------------------------------------------------
    localparam IDLE   = 3'b000,
               WSEND  = 3'b001,    // Send write via UART
               RSEND  = 3'b010,    // Send read request via UART
               RDATA  = 3'b011,    // Wait for UART read response
               LOCAL  = 3'b100,    // Local memory operation
               WBUSY  = 3'b101,    // Wait for UART TX busy after write
               RBUSY  = 3'b110;    // Wait for UART TX busy after read request
    
    reg [2:0] state, next_state;

    //--------------------------------------------------------------------------
    // Split Grant Gating Logic (placed after state declaration)
    //--------------------------------------------------------------------------
    // For bridge operations (UART), we must NOT grant split until UART response arrives.
    // For local memory operations, split_grant passes through normally.
    // 
    // The problem: arbiter's split_grant is based on bus timing, not UART timing.
    // Solution: Gate split_grant for bridge reads - only pass through when:
    //   1. Local access: use arbiter's split_grant directly
    //   2. Bridge read: only grant when UART response received (rdata_received)
    //   3. Bridge write: use arbiter's split_grant (write doesn't need response)
    //
    // When bus_bridge_slave state is RSEND, RBUSY, or RDATA, we're doing a UART bridge
    // read and must wait for rdata_received before allowing split_grant through.
    //--------------------------------------------------------------------------
    wire bridge_read_in_progress;
    
    // Track if we're in the middle of a bridge read operation
    assign bridge_read_in_progress = (state == RSEND) || (state == RBUSY) || (state == RDATA);
    
    // For bridge reads, only grant when UART response is received
    // For local operations or bridge writes, pass through arbiter's grant
    assign sp_split_grant = bridge_read_in_progress ? (split_grant && rdata_received) : split_grant;

    //--------------------------------------------------------------------------
    // Extended Split Signal (ssplit)
    //--------------------------------------------------------------------------
    // For bridge read operations, we need to keep ssplit HIGH until UART response
    // is received. This prevents master_port from leaving SPLIT state prematurely.
    //
    // Normal slave_port: ssplit is high only in SPLIT state
    // Extended for bridge: ssplit stays high during SPLIT, WAIT, and until data ready
    //
    // ssplit is high when:
    //   1. slave_port is in SPLIT state (sp_ssplit), OR
    //   2. We're doing a bridge read AND haven't received response yet
    //--------------------------------------------------------------------------
    assign ssplit = sp_ssplit || (bridge_read_in_progress && !rdata_received);

    //--------------------------------------------------------------------------
    // Latch address and data when write/read enable becomes active
    // 
    // IMPORTANT TIMING: slave_port uses non-blocking assignments:
    //   smemwen <= 1; smemaddr <= addr;
    // These take effect at the END of the clock cycle. So when bus_bridge_slave
    // sees sp_memwen=1 for the first time, sp_memaddr still has the OLD value!
    // We need to capture the values ONE CYCLE LATER (or use registered detection).
    //
    // Solution: Use a 2-cycle detection:
    // Cycle N:   sp_memwen goes high, sp_memaddr still has old value
    // Cycle N+1: sp_memwen stays high (for at least one more cycle in slave_port 
    //            transition), sp_memaddr now has correct value - LATCH HERE
    // Actually slave_port goes SREADY->IDLE in one cycle, so sp_memwen is only high
    // for ONE cycle. But the NON-BLOCKING assignment means:
    // - At clock edge N: SREADY logic executes, schedules smemwen=1, smemaddr=addr
    // - After clock edge N: smemwen becomes 1, smemaddr becomes correct
    // - At clock edge N+1: IDLE logic executes, schedules smemwen=0
    // - bus_bridge_slave at clock edge N+1: sees smemwen=1, smemaddr=correct!
    //
    // So we should latch when we FIRST see sp_memwen=1 (rising edge detection)
    // and the address should be correct at that point.
    //--------------------------------------------------------------------------
    reg prev_sp_memwen, prev_sp_memren;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            latched_wdata   <= {DATA_WIDTH{1'b0}};
            latched_addr    <= {ADDR_WIDTH{1'b0}};
            pending_write   <= 1'b0;
            pending_read    <= 1'b0;
            prev_sp_memwen  <= 1'b0;
            prev_sp_memren  <= 1'b0;
        end else begin
            prev_sp_memwen <= sp_memwen;
            prev_sp_memren <= sp_memren;
            
            // Rising edge of sp_memwen - at this clock edge, sp_memaddr should be valid
            // because it was set by the previous clock edge's non-blocking assignment
            if (sp_memwen && !prev_sp_memwen && state == IDLE) begin
                latched_wdata <= sp_memwdata;
                latched_addr  <= sp_memaddr;
                $display("[BUS_BRIDGE_SLAVE %m @%0t] Detected WRITE rising edge: addr=0x%03h, data=0x%02h, addr[11]=%b", 
                         $time, sp_memaddr, sp_memwdata, sp_memaddr[LOCAL_ADDR_MSB]);
                // Check bridge access using the current address value
                if (sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE) begin
                    pending_write <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE %m @%0t] -> BRIDGE write pending", $time);
                end else begin
                    $display("[BUS_BRIDGE_SLAVE %m @%0t] -> LOCAL write (not bridge)", $time);
                end
            end
            // Rising edge of sp_memren
            else if (sp_memren && !prev_sp_memren && state == IDLE) begin
                latched_addr  <= sp_memaddr;
                $display("[BUS_BRIDGE_SLAVE %m @%0t] Detected READ rising edge: addr=0x%03h, addr[11]=%b", 
                         $time, sp_memaddr, sp_memaddr[LOCAL_ADDR_MSB]);
                if (sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE) begin
                    pending_read  <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE %m @%0t] -> BRIDGE read pending", $time);
                end else begin
                    $display("[BUS_BRIDGE_SLAVE %m @%0t] -> LOCAL read (not bridge)", $time);
                end
            end
            // Clear pending flags when entering WSEND/RSEND states
            else if (state == WSEND || state == RSEND) begin
                pending_write <= 1'b0;
                pending_read  <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // UART TX start tracking
    // We need to wait one cycle after entering WBUSY/RBUSY before checking u_tx_busy
    // because the UART TX module takes one clock cycle to start after seeing data_en
    //--------------------------------------------------------------------------
    reg uart_tx_started;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            uart_tx_started <= 1'b0;
        else if (state == WSEND || state == RSEND)
            uart_tx_started <= 1'b0;  // Reset when entering busy wait states
        else if ((state == WBUSY || state == RBUSY) && u_tx_busy)
            uart_tx_started <= 1'b1;  // Mark that TX has started
        else if (state == IDLE)
            uart_tx_started <= 1'b0;  // Clear when back to IDLE
    end

    //--------------------------------------------------------------------------
    // Next State Logic (uses pending flags instead of direct sp_memwen/sp_memren)
    // WSEND/RSEND states immediately transition to WBUSY/RBUSY to wait for UART
    //--------------------------------------------------------------------------
    always @(*) begin
        case (state)
            IDLE: begin
                if (pending_write)
                    next_state = WSEND;
                else if (pending_read)
                    next_state = RSEND;
                else if ((sp_memwen || sp_memren) && is_local_access_now)
                    next_state = LOCAL;
                else
                    next_state = IDLE;
            end
            WSEND:  next_state = WBUSY;  // Always go to WBUSY to wait for TX to start
            // Wait until TX has started AND completed (tx_busy goes high then low)
            WBUSY:  next_state = (uart_tx_started && !u_tx_busy) ? IDLE : WBUSY;
            RSEND:  next_state = RBUSY;  // Always go to RBUSY to wait for TX to start
            // Wait until TX has started AND completed, then wait for response
            RBUSY:  next_state = (uart_tx_started && !u_tx_busy) ? RDATA : RBUSY;
            RDATA:  next_state = (!sp_memren) ? IDLE : RDATA;
            LOCAL:  next_state = (!sp_memwen && !sp_memren) ? IDLE : LOCAL;
            default: next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // State Transition Logic (async reset)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else begin
            if (state == IDLE && (sp_memwen || sp_memren)) begin
                $display("[BUS_BRIDGE_SLAVE %m @%0t] IDLE state: sp_memwen=%b, sp_memren=%b, is_bridge=%b, is_local=%b, addr=0x%03h",
                         $time, sp_memwen, sp_memren, is_bridge_access, is_local_access, sp_memaddr);
            end
            if (state != next_state) begin
                $display("[BUS_BRIDGE_SLAVE %m @%0t] STATE: %0s -> %0s (u_tx_busy=%b, u_en=%b)",
                         $time, 
                         state == IDLE ? "IDLE" : state == WSEND ? "WSEND" : state == RSEND ? "RSEND" :
                         state == RDATA ? "RDATA" : state == LOCAL ? "LOCAL" : 
                         state == WBUSY ? "WBUSY" : state == RBUSY ? "RBUSY" : "UNKNOWN",
                         next_state == IDLE ? "IDLE" : next_state == WSEND ? "WSEND" : next_state == RSEND ? "RSEND" :
                         next_state == RDATA ? "RDATA" : next_state == LOCAL ? "LOCAL" :
                         next_state == WBUSY ? "WBUSY" : next_state == RBUSY ? "RBUSY" : "UNKNOWN",
                         u_tx_busy, u_en);
            end
            // Debug WBUSY state every cycle
            if (state == WBUSY || state == RBUSY) begin
                $display("[BUS_BRIDGE_SLAVE %m @%0t] %s: u_tx_busy=%b, uart_tx_started=%b, u_en=%b",
                         $time, state == WBUSY ? "WBUSY" : "RBUSY", u_tx_busy, uart_tx_started, u_en);
            end
            state <= next_state;
        end
    end

    //--------------------------------------------------------------------------
    // UART Receive Data Latching (async reset)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            latched_rdata   <= {DATA_WIDTH{1'b0}};
            rdata_received  <= 1'b0;
            prev_u_rx_ready <= 1'b0;
        end
        else begin
            prev_u_rx_ready <= u_rx_ready;
            
            if (state == IDLE) begin
                rdata_received <= 1'b0;
                latched_rdata  <= {DATA_WIDTH{1'b0}};
            end
            else if (state == RDATA && u_rx_ready && !prev_u_rx_ready) begin
                latched_rdata  <= u_dout;
                rdata_received <= 1'b1;
                $display("[BUS_BRIDGE_SLAVE @%0t] UART RX received: 0x%02h", $time, u_dout);
            end
        end
    end

    //--------------------------------------------------------------------------
    // UART Transmit Control (async reset) - Uses latched values
    // Only assert u_en in WSEND/RSEND states for ONE cycle
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            u_din <= {UART_TX_DATA_WIDTH{1'b0}};
            u_en  <= 1'b0;
        end
        else begin
            case (state) 
                IDLE: begin
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
                
                WSEND: begin
                    // Send: {mode=1, data, addr} - full address width
                    // Use latched values for correct data
                    u_din <= {1'b1, latched_wdata, latched_addr};
                    u_en  <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE @%0t] UART TX write: addr=0x%03h, data=0x%02h", 
                             $time, latched_addr, latched_wdata);
                end
                
                WBUSY: begin
                    // Keep data, but deassert enable - UART should be busy now
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
                
                RSEND: begin
                    // Send: {mode=0, 0, addr} - full address width
                    // Use latched address
                    u_din <= {1'b0, {DATA_WIDTH{1'b0}}, latched_addr};
                    u_en  <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE @%0t] UART TX read request: addr=0x%03h", 
                             $time, latched_addr);
                end
                
                RBUSY: begin
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
                
                RDATA: begin
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
                
                LOCAL: begin
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
                
                default: begin
                    u_din <= u_din;
                    u_en  <= 1'b0;
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Read Data Multiplexing and Valid Generation
    //--------------------------------------------------------------------------
    // Select read data source based on access type
    wire bridge_rvalid = (state == RDATA) && rdata_received;
    
    // Read data mux: local memory or UART response
    assign sp_memrdata = (state == RDATA) ? (rdata_received ? latched_rdata : u_dout) :
                         (state == LOCAL) ? lmem_rdata : {DATA_WIDTH{1'b0}};
    
    // Read valid: either from local memory or UART response
    always @(*) begin
        if (state == LOCAL)
            sp_rvalid = lmem_rvalid;
        else if (state == RDATA)
            sp_rvalid = rdata_received;
        else
            sp_rvalid = 1'b0;
    end
    
    //--------------------------------------------------------------------------
    // Ready Signal
    //--------------------------------------------------------------------------
    // Slave is ready when: slave_port is ready AND not busy with UART AND state is IDLE
    assign sready = sp_ready && !sp_memwen && !sp_memren && (state == IDLE);

endmodule
