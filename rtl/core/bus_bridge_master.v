//==============================================================================
// File: bus_bridge_master_v2.v
// Description: Bus Bridge Master module with local memory and UART bridge
//              
//              This module acts as a master on the local bus and can:
//              1. Execute transactions on local bus from UART commands (bridge mode)
//              2. Store data in local BRAM (accessed through device interface)
//
// Operation Modes:
//   1. Bridge Mode: Receives commands via UART from remote system, executes
//                   read/write transactions on local bus via master_port
//   2. Local Mode:  Local device can access the master's internal BRAM
//
// Data from UART should be sent as: {mode, data, addr}
//
// Architecture:
//   +-----------------------------------------------------------+
//   |                 bus_bridge_master_v2.v                    |
//   |  +--------------+   +-------------+   +----------------+  |
//   |  | master_port  |---|  Controller |---| master_memory  |  |
//   |  | (bus access) |   |   (FSM)     |   |    _bram       |  |
//   |  +--------------+   +-------------+   | (local store)  |  |
//   |         |                 |           +----------------+  |
//   |         |           +----------+           |              |
//   |         |           |   UART   |<-- RX from remote        |
//   |         |           |   FIFO   |--> TX to remote          |
//   |         |           +----------+                          |
//   +---------|------------------------------------------+-----+
//             |                                          |
//         to/from local bus                          UART lines
//
//==============================================================================
// Author: ADS Bus System
// Date: 2025-12-02
//==============================================================================

`timescale 1ns / 1ps

module bus_bridge_master #(
    parameter ADDR_WIDTH = 16, 
    parameter DATA_WIDTH = 8,
    parameter SLAVE_MEM_ADDR_WIDTH = 12,
    parameter BB_ADDR_WIDTH = 12,
    parameter UART_CLOCKS_PER_PULSE = 5208,
    parameter LOCAL_MEM_SIZE = 2048,       // Local memory size
    parameter LOCAL_MEM_ADDR_WIDTH = 11,   // log2(LOCAL_MEM_SIZE)
    parameter ENABLE_ADAPTERS = 0          // Enable protocol adapters for other team's system
)(
    input clk, rstn,
    
    //--------------------------------------------------------------------------
    // Serial Bus Interface (as a master)
    //--------------------------------------------------------------------------
    input  wire mrdata,        // Read data from bus
    output wire mwdata,        // Write data and address to bus
    output wire mmode,         // 0 - read, 1 - write
    output wire mvalid,        // Write data valid
    input  wire svalid,        // Read data valid from slave

    //--------------------------------------------------------------------------
    // Arbiter Interface
    //--------------------------------------------------------------------------
    output wire mbreq,         // Bus request
    input  wire mbgrant,       // Bus grant
    input  wire msplit,        // Split signal

    //--------------------------------------------------------------------------
    // Address Decoder Interface
    //--------------------------------------------------------------------------
    input  wire ack,           // Acknowledgement

    //--------------------------------------------------------------------------
    // Local Memory Interface - Direct access to master's internal BRAM
    //--------------------------------------------------------------------------
    input  wire                     lmem_wen,    // Local memory write enable
    input  wire                     lmem_ren,    // Local memory read enable
    input  wire [LOCAL_MEM_ADDR_WIDTH-1:0] lmem_addr, // Local memory address
    input  wire [DATA_WIDTH-1:0]    lmem_wdata,  // Local memory write data
    output wire [DATA_WIDTH-1:0]    lmem_rdata,  // Local memory read data
    output wire                     lmem_rvalid, // Local memory read valid

    //--------------------------------------------------------------------------
    // Bus Bridge UART Interface (connecting to remote system)
    //--------------------------------------------------------------------------
    output wire u_tx,          // UART transmit (send read data back)
    input  wire u_rx           // UART receive (receive commands)
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam UART_RX_DATA_WIDTH = DATA_WIDTH + BB_ADDR_WIDTH + 1;  // Receive: mode + data + addr
    localparam UART_TX_DATA_WIDTH = DATA_WIDTH;                      // Transmit: only read data
    
    //--------------------------------------------------------------------------
    // Signals to Master Port
    //--------------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0]    dwdata;        // Write data to master port
    wire [DATA_WIDTH-1:0]    drdata;        // Read data from master port
    wire [ADDR_WIDTH-1:0]    daddr;         // Address to master port
    reg                      dvalid;        // Transaction valid
    wire                     dready;        // Master port ready
    reg                      dmode;         // Transaction mode

    //--------------------------------------------------------------------------
    // FIFO Signals
    //--------------------------------------------------------------------------
    reg                              fifo_enq;
    reg                              fifo_deq;
    reg  [UART_RX_DATA_WIDTH-1:0]    fifo_din;
    wire [UART_RX_DATA_WIDTH-1:0]    fifo_dout;
    wire                             fifo_empty;

    //--------------------------------------------------------------------------
    // UART Signals (Direct mode - no adapters)
    //--------------------------------------------------------------------------
    reg  [UART_TX_DATA_WIDTH-1:0]    u_din;
    reg                              u_en;
    wire                             u_tx_busy;
    wire                             u_rx_ready_direct;    // Direct UART RX ready
    wire [UART_RX_DATA_WIDTH-1:0]    u_dout_direct;       // Direct UART RX data
    
    //--------------------------------------------------------------------------
    // RX Adapter Signals (for other team's protocol)
    //--------------------------------------------------------------------------
    wire [7:0]  rx_adapter_uart_data;           // Data from their UART
    wire        rx_adapter_uart_ready;          // Their UART ready
    reg         rx_adapter_uart_ready_clr;      // Clear ready
    wire [7:0]  rx_adapter_frame_out;           // Frame from RX adapter
    wire        rx_adapter_frame_valid;         // Frame valid from adapter
    wire        rx_adapter_frame_ready;         // We're ready for frame
    
    // Multiplexed signals based on adapter enable
    wire                             u_rx_ready;     // Final RX ready
    wire [UART_RX_DATA_WIDTH-1:0]    u_dout;        // Final RX data

    //--------------------------------------------------------------------------
    // Internal Control Signals
    //--------------------------------------------------------------------------
    reg  [BB_ADDR_WIDTH-1:0] bb_addr;
    reg                      expect_rdata;
    reg                      prev_u_ready;
    reg                      prev_m_ready;

    //--------------------------------------------------------------------------
    // Master Port Instantiation
    //--------------------------------------------------------------------------
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE_MEM_ADDR_WIDTH)
    ) master (
        .clk(clk),
        .rstn(rstn),
        .dwdata(dwdata),
        .drdata(drdata),
        .daddr(daddr),
        .dvalid(dvalid),
        .dready(dready),
        .dmode(dmode),
        .mrdata(mrdata),
        .mwdata(mwdata),
        .mmode(mmode),
        .mvalid(mvalid),
        .svalid(svalid),
        .mbreq(mbreq),
        .mbgrant(mbgrant),
        .msplit(msplit),
        .ack(ack)
    );

    //--------------------------------------------------------------------------
    // FIFO Module Instantiation
    //--------------------------------------------------------------------------
    fifo #(
        .DATA_WIDTH(UART_RX_DATA_WIDTH),
        .DEPTH(8)
    ) fifo_queue (
        .clk(clk),
        .rstn(rstn),
        .enq(fifo_enq),
        .deq(fifo_deq),
        .data_in(fifo_din),
        .data_out(fifo_dout),
        .empty(fifo_empty)
    );

    //--------------------------------------------------------------------------
    // UART Module Instantiation (Direct mode - 21-bit frames)
    // RX receives 21-bit commands, TX sends 8-bit read responses
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
        .ready(u_rx_ready_direct),   
        .data_output(u_dout_direct)
    );
    
    //--------------------------------------------------------------------------
    // RX Adapter Module (for other team's protocol)
    // Converts 4-byte sequence to 21-bit frame
    // Note: Other team sends commands as 4-byte sequence, we receive via RX adapter
    // Their response is 2-byte sequence which goes through RX adapter
    //--------------------------------------------------------------------------
    generate
        if (ENABLE_ADAPTERS == 1) begin : rx_adapter_gen
            // Instantiate UART RX for adapter (8-bit per byte, 115200 baud)
            uart_rx #(
                .CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),  // Should be 434 for 115200
                .DATA_WIDTH(8)
            ) adapter_uart_rx (
                .clk(clk),
                .rstn(rstn),
                .rx(u_rx),
                .ready(rx_adapter_uart_ready),
                .data_out(rx_adapter_uart_data)
            );
            
            // Instantiate RX adapter
            uart_to_other_team_rx_adapter rx_adapter (
                .clk(clk),
                .rstn(rstn),
                .uart_data_out(rx_adapter_uart_data),
                .uart_ready(rx_adapter_uart_ready),
                .uart_ready_clr(rx_adapter_uart_ready_clr),
                .frame_out(rx_adapter_frame_out),
                .frame_valid(rx_adapter_frame_valid),
                .frame_ready(rx_adapter_frame_ready),
                .clk_50m(clk)
            );
            
            // Map adapter outputs to internal signals
            // For bridge master, we expect 21-bit commands but adapter gives 8-bit data
            // We need to reconstruct: their 2-byte response → our 8-bit read data
            assign u_rx_ready = rx_adapter_frame_valid;
            // Pad the 8-bit adapter output to match expected width
            // Since this is for READ RESPONSES (2-byte from them → 8-bit data for us)
            // The adapter already extracts just the data byte
            assign u_dout = {{(UART_RX_DATA_WIDTH-8){1'b0}}, rx_adapter_frame_out};
            assign rx_adapter_frame_ready = 1'b1;  // Always ready
            
        end else begin : no_adapter
            // Direct connection without adapter
            assign u_rx_ready = u_rx_ready_direct;
            assign u_dout = u_dout_direct;
        end
    endgenerate

    //--------------------------------------------------------------------------
    // Address Converter - Maps BB address to full bus address
    //--------------------------------------------------------------------------
    addr_convert #(
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .BUS_ADDR_WIDTH(ADDR_WIDTH),
        .BUS_MEM_ADDR_WIDTH(SLAVE_MEM_ADDR_WIDTH)
    ) addr_convert_module (
        .bb_addr(bb_addr),
        .bus_addr(daddr)
    );

    //--------------------------------------------------------------------------
    // Local Memory BRAM Instantiation
    //--------------------------------------------------------------------------
    master_memory_bram #(
        .ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_SIZE(LOCAL_MEM_SIZE)
    ) local_mem (
        .clk(clk),
        .rstn(rstn),
        .wen(lmem_wen),
        .ren(lmem_ren),
        .addr(lmem_addr),
        .wdata(lmem_wdata),
        .rdata(lmem_rdata),
        .rvalid(lmem_rvalid)
    );

    //--------------------------------------------------------------------------
    // UART RX to FIFO Logic (async reset)
    // Enqueue received UART data into FIFO
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            fifo_din     <= {UART_RX_DATA_WIDTH{1'b0}};
            fifo_enq     <= 1'b0;
            prev_u_ready <= 1'b0;
        end
        else begin
            prev_u_ready <= u_rx_ready;

            if (u_rx_ready && !prev_u_ready) begin
                fifo_din <= u_dout;
                fifo_enq <= 1'b1;
                $display("[BUS_BRIDGE_MASTER @%0t] UART RX -> FIFO: 0x%05h (mode=%b, data=0x%02h, addr=0x%03h)", 
                         $time, u_dout, u_dout[BB_ADDR_WIDTH + DATA_WIDTH], 
                         u_dout[BB_ADDR_WIDTH +: DATA_WIDTH], u_dout[BB_ADDR_WIDTH-1:0]);
            end
            else begin
                fifo_din <= fifo_din;
                fifo_enq <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // FIFO to Master Port Logic (async reset)
    // Dequeue FIFO data and initiate bus transactions
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            bb_addr      <= {BB_ADDR_WIDTH{1'b0}};
            dwdata       <= {DATA_WIDTH{1'b0}};
            dmode        <= 1'b0;
            dvalid       <= 1'b0;
            fifo_deq     <= 1'b0;
            expect_rdata <= 1'b0;
        end
        else begin
            if (dready && !fifo_empty && !dvalid) begin
                bb_addr      <= fifo_dout[BB_ADDR_WIDTH-1:0];
                dwdata       <= fifo_dout[BB_ADDR_WIDTH +: DATA_WIDTH];
                dmode        <= fifo_dout[BB_ADDR_WIDTH + DATA_WIDTH];
                dvalid       <= 1'b1;
                fifo_deq     <= 1'b1;
                expect_rdata <= ~fifo_dout[BB_ADDR_WIDTH + DATA_WIDTH];  // Expect read data if mode=0
                
                $display("[BUS_BRIDGE_MASTER @%0t] FIFO -> Master: addr=0x%03h, data=0x%02h, mode=%s", 
                         $time, fifo_dout[BB_ADDR_WIDTH-1:0], 
                         fifo_dout[BB_ADDR_WIDTH +: DATA_WIDTH],
                         fifo_dout[BB_ADDR_WIDTH + DATA_WIDTH] ? "WRITE" : "READ");
            end
            else begin
                bb_addr      <= bb_addr;
                dwdata       <= dwdata;
                dmode        <= dmode;
                dvalid       <= 1'b0;
                fifo_deq     <= 1'b0;
                expect_rdata <= expect_rdata;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Master Port to UART TX Logic (async reset)
    // Send read data back via UART after bus read completes
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            u_din        <= {UART_TX_DATA_WIDTH{1'b0}};
            u_en         <= 1'b0;
            prev_m_ready <= 1'b0;
        end
        else begin
            prev_m_ready <= dready;
            
            // Read transaction finished - send data back via UART
            if (!prev_m_ready && dready && expect_rdata) begin
                u_din <= drdata;
                u_en  <= 1'b1;
                $display("[BUS_BRIDGE_MASTER @%0t] Master -> UART TX: read_data=0x%02h", $time, drdata);
            end
            else begin
                u_din <= u_din;
                u_en  <= 1'b0;
            end
        end
    end

endmodule
