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
    reg                   rdata_received;    // Flag: UART data received
    reg                   prev_u_rx_ready;   // Previous UART ready state
    wire                  is_bridge_access;  // Address indicates bridge access
    wire                  is_local_access;   // Address indicates local memory access

    //--------------------------------------------------------------------------
    // Address Decode Logic
    //--------------------------------------------------------------------------
    assign is_bridge_access = sp_memaddr[LOCAL_ADDR_MSB] & BRIDGE_ENABLE;
    assign is_local_access  = ~sp_memaddr[LOCAL_ADDR_MSB];
    
    // Local memory signals
    assign lmem_wen  = sp_memwen & is_local_access;
    assign lmem_ren  = sp_memren & is_local_access;
    assign lmem_addr = sp_memaddr[ADDR_WIDTH-2:0];

    //--------------------------------------------------------------------------
    // Slave Port Instantiation
    //--------------------------------------------------------------------------
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
        .split_grant(split_grant),
        .svalid(svalid),	
        .sready(sp_ready),
        .ssplit(ssplit)
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
               LOCAL  = 3'b100;    // Local memory operation
    
    reg [2:0] state, next_state;

    //--------------------------------------------------------------------------
    // Next State Logic
    //--------------------------------------------------------------------------
    always @(*) begin
        case (state)
            IDLE: begin
                if (sp_memwen && is_bridge_access)
                    next_state = WSEND;
                else if (sp_memren && is_bridge_access)
                    next_state = RSEND;
                else if ((sp_memwen || sp_memren) && is_local_access)
                    next_state = LOCAL;
                else
                    next_state = IDLE;
            end
            WSEND:  next_state = (u_tx_busy) ? WSEND : IDLE;
            RSEND:  next_state = (u_tx_busy) ? RSEND : RDATA;
            RDATA:  next_state = (!sp_memren) ? IDLE : RDATA;
            LOCAL:  next_state = (!sp_memwen && !sp_memren) ? IDLE : LOCAL;
            default: next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // State Transition Logic
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        state <= (!rstn) ? IDLE : next_state;
    end

    //--------------------------------------------------------------------------
    // UART Receive Data Latching (for read responses)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
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
    // UART Transmit Control
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
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
                    // Send: {mode=1, data, addr[ADDR_WIDTH-2:0]}
                    u_din <= {1'b1, sp_memwdata, sp_memaddr[ADDR_WIDTH-2:0]};
                    u_en  <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE @%0t] UART TX write: addr=0x%03h, data=0x%02h", 
                             $time, sp_memaddr[ADDR_WIDTH-2:0], sp_memwdata);
                end
                
                RSEND: begin
                    // Send: {mode=0, 0, addr[ADDR_WIDTH-2:0]}
                    u_din <= {1'b0, {DATA_WIDTH{1'b0}}, sp_memaddr[ADDR_WIDTH-2:0]};
                    u_en  <= 1'b1;
                    $display("[BUS_BRIDGE_SLAVE @%0t] UART TX read request: addr=0x%03h", 
                             $time, sp_memaddr[ADDR_WIDTH-2:0]);
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
