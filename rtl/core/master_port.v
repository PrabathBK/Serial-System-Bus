//-----------------------------------------------------------------------------
// Module: master_port
// Description: Master port interface for ADS serial bus system
//              8-state FSM handling bus transactions (read/write)
//              Supports split transaction protocol
//
// Parameters:
//   ADDR_WIDTH - Address width (default: 16 bits)
//   DATA_WIDTH - Data width (default: 8 bits)
//   SLAVE_MEM_ADDR_WIDTH - Slave memory address width (default: 12 bits)
//
// Functionality:
//   - Requests bus access via arbiter
//   - Sends device address (4-bit) then memory address (12-bit) serially
//   - Performs write (sends data) or read (receives data) operations
//   - Handles split transactions with automatic retry
//   - Timeout mechanism for invalid addresses
//
// Author: ADS Bus System Generator
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps

module master_port #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter SLAVE_MEM_ADDR_WIDTH = 12
)(
    input clk,
    input rstn,
    
    // Signals connecting to master device
    input  [DATA_WIDTH-1:0] dwdata,          // write data
    output [DATA_WIDTH-1:0] drdata,          // read data
    input  [ADDR_WIDTH-1:0] daddr,           // address
    input                   dvalid,          // data valid
    output                  dready,          // ready for transaction
    input                   dmode,           // 0 - read, 1 - write
    
    // Signals connecting to serial bus
    input                   mrdata,          // read data (serial)
    output reg              mwdata,          // write data and address (serial)
    output                  mmode,           // 0 - read, 1 - write
    output reg              mvalid,          // wdata valid
    input                   svalid,          // rdata valid
    
    // Signals to arbiter
    output                  mbreq,           // bus request
    input                   mbgrant,         // bus grant
    input                   msplit,          // split signal
    
    // Acknowledgement from address decoder
    input                   ack
);

    localparam SLAVE_DEVICE_ADDR_WIDTH = ADDR_WIDTH - SLAVE_MEM_ADDR_WIDTH;
    localparam TIMEOUT_TIME = 5;
    
    /* Internal signals */
    // Registers to accept data from master device and slave
    reg [DATA_WIDTH-1:0] wdata;
    reg [ADDR_WIDTH-1:0] addr;
    reg                  mode;
    reg [DATA_WIDTH-1:0] rdata;
    
    // Counters
    reg [7:0] counter, timeout;
    
    // States
    localparam IDLE  = 3'b000,
               ADDR  = 3'b001,    // Send address to slave
               RDATA = 3'b010,    // Read data from slave
               WDATA = 3'b011,    // Write data to slave
               REQ   = 3'b100,    // Request bus access
               SADDR = 3'b101,    // Send slave device address
               WAIT  = 3'b110,    // Wait for acknowledgement
               SPLIT = 3'b111;    // Wait for split slave to be ready
    
    // State variables
    reg [2:0] state, next_state, prev_state;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE  : next_state = (dvalid) ? REQ : IDLE;
            REQ   : next_state = (mbgrant) ? SADDR : REQ;
            SADDR : next_state = (counter == SLAVE_DEVICE_ADDR_WIDTH-1) ? WAIT : SADDR;
            WAIT  : next_state = (ack) ? ADDR : ((timeout == TIMEOUT_TIME) ? IDLE : WAIT);
            ADDR  : next_state = (counter == SLAVE_MEM_ADDR_WIDTH-1) ? ((mode) ? WDATA : RDATA) : ADDR;
            RDATA : next_state = (msplit) ? SPLIT : ((svalid && (counter == DATA_WIDTH-1)) ? IDLE : RDATA);
            WDATA : next_state = (counter == DATA_WIDTH-1) ? IDLE : WDATA;
            SPLIT : next_state = (!msplit && mbgrant) ? RDATA : SPLIT;
            default: next_state = IDLE;
        endcase
    end
    
    // State transition logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            prev_state <= IDLE;
        end else begin
            prev_state <= state;
            state <= next_state;
        end
    end
    
    // Combinational output assignments
    assign dready = (state == IDLE);
    assign drdata = rdata;
    assign mmode  = mode;
    assign mbreq  = (state != IDLE);  // Keep bus request while master is in need of the bus
    
    // Sequential output logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wdata   <= 'b0;
            rdata   <= 'b0;
            addr    <= 'b0;
            mode    <= 0;
            counter <= 'b0;
            mvalid  <= 0;
            mwdata  <= 0;
            timeout <= 'b0;
        end
        else begin
            case (state)
                IDLE : begin
                    counter <= 'b0;
                    mvalid  <= 0;
                    timeout <= 'b0;
                    if (dvalid) begin  // Have to send data
                        wdata <= dwdata;
                        addr  <= daddr;
                        mode  <= dmode;
                        // Don't clear rdata - it holds the previous read result until overwritten
                    end else begin
                        wdata <= wdata;
                        addr  <= addr;
                        mode  <= mode;
                    end
                end
                
                REQ : begin
                    // Wait for bus grant
                end
                
                SADDR : begin  // Send slave device address (LSB-first, bits [15:12])
                    mwdata <= addr[SLAVE_MEM_ADDR_WIDTH + counter];
                    mvalid <= 1'b1;
                    if (counter == SLAVE_DEVICE_ADDR_WIDTH-1) begin
                        counter <= 'b0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                WAIT : begin
                    mvalid  <= 1'b0;
                    timeout <= timeout + 1;
                end
                
                ADDR : begin  // Send slave mem address
                    mwdata <= addr[counter];
                    mvalid <= 1'b1;
                    if (counter == SLAVE_MEM_ADDR_WIDTH-1) begin
                        counter <= 'b0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                RDATA : begin  // Receive data from slave
                    mvalid <= 1'b0;
                    if (svalid) begin
                        rdata[counter] <= mrdata;
                        if (counter == DATA_WIDTH-1) begin
                            counter <= 'b0;
                        end else begin
                            counter <= counter + 1;
                        end
                    end else begin
                        rdata   <= rdata;
                        counter <= counter;
                    end
                end
                
                WDATA : begin  // Send data to slave
                    // Add setup cycle delay to sync with slave's ADDR->WDATA skip cycle
                    if (prev_state == ADDR && state == WDATA) begin
                        // First cycle after ADDR->WDATA: setup time, don't transmit yet
                        mvalid <= 1'b0;
                        mwdata <= 1'b0;
                    end else begin
                        // Normal transmission
                        mwdata <= wdata[counter];
                        mvalid <= 1'b1;
                        if (counter == DATA_WIDTH-1) begin
                            counter <= 'b0;

                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end
                
                SPLIT : begin
                    mvalid <= 1'b0;
                end
                
                default: begin
                    wdata   <= wdata;
                    rdata   <= rdata;
                    addr    <= addr;
                    mode    <= mode;
                    counter <= counter;
                    mvalid  <= mvalid;
                    mwdata  <= mwdata;
                    timeout <= timeout;
                end
            endcase
        end
    end

endmodule
