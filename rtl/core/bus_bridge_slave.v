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
    parameter BRIDGE_ENABLE = 1            // Enable UART bridge functionality
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
    localparam SPLIT_EN = 1'b1;  // Enable split for UART operations 
    
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
    // Internal Signals - UART
    //--------------------------------------------------------------------------
    reg  [UART_TX_DATA_WIDTH-1:0] u_din;     // UART transmit data
    reg                           u_en;       // UART transmit enable
    wire                          u_tx_busy;  // UART transmitter busy
    wire                          u_rx_ready; // UART receive data ready
    wire [UART_RX_DATA_WIDTH-1:0] u_dout;    // UART receive data

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
    // UART Module Instantiation (for bridge operations)
    //--------------------------------------------------------------------------
    uart #(
        .CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .TX_DATA_WIDTH(UART_TX_DATA_WIDTH),
        .RX_DATA_WIDTH(UART_RX_DATA_WIDTH)
    ) uart_module (
        .data_input(u_din),
        .data_en(u_en),
        .clk(clk),
        .rstn(rstn),
        .tx(u_tx),
        .tx_busy(u_tx_busy),
        .rx(u_rx),  
        .ready(u_rx_ready),   
        .data_output(u_dout)
    );

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
    assign bridge_read_in_progress = (state == RSEND) || (state == RBUSY) || (state == RDATA);
    assign sp_split_grant = bridge_read_in_progress ? (split_grant && rdata_received) : split_grant;
    assign ssplit = sp_ssplit || (bridge_read_in_progress && !rdata_received);
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
                // Check bridge access using the current address value
                if (sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE) begin
                    pending_write <= 1'b1;

                end else begin

                end
            end
            // Rising edge of sp_memren
            else if (sp_memren && !prev_sp_memren && state == IDLE) begin
                latched_addr  <= sp_memaddr;
                if (sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE) begin
                    pending_read  <= 1'b1;

                end else begin

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
            end
            if (state != next_state) begin
            end
            // Debug WBUSY state every cycle
            if (state == WBUSY || state == RBUSY) begin
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
