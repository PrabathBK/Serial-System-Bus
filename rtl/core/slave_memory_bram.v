//==============================================================================
// File: slave_memory_bram.v
// Description: Slave memory module with BRAM instantiation
//              Supports configurable memory sizes (2KB or 4KB)
//              Generates rvalid signal one cycle after read enable
//              Clears memory to zero on reset
//==============================================================================
// Author: ADS Bus System
// Date: 2025-10-14
//==============================================================================


`timescale 1ns / 1ps

module slave_memory_bram #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 8,
    parameter MEM_SIZE = 4096  // Memory size in bytes (2048 or 4096)
)(
    input  wire                     clk,
    input  wire                     rstn,
    input  wire                     wen,        // Write enable
    input  wire                     ren,        // Read enable
    input  wire [ADDR_WIDTH-1:0]    addr,       // Address input
    input  wire [DATA_WIDTH-1:0]    wdata,      // Write data
    output reg  [DATA_WIDTH-1:0]    rdata,      // Read data
    output reg                      rvalid      // Read data valid
);

    //--------------------------------------------------------------------------
    // Local Parameters
    //--------------------------------------------------------------------------
    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    reg ren_prev;  // Previous cycle read enable
    
    // Memory clear control
    reg clearing;
    reg [MEM_ADDR_WIDTH-1:0] clear_addr;

    //--------------------------------------------------------------------------
    // Memory Array Declaration
    //--------------------------------------------------------------------------
    // Behavioral memory for simulation and synthesis
    // Will be inferred as M9K blocks by Quartus for Cyclone IV
    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];

    //--------------------------------------------------------------------------
    // Memory Clear FSM (async reset trigger)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            clearing   <= 1'b1;
            clear_addr <= {MEM_ADDR_WIDTH{1'b0}};
        end
        else if (clearing) begin
            if (clear_addr == MEM_SIZE - 1)
                clearing <= 1'b0;
            else
                clear_addr <= clear_addr + 1'b1;
        end
    end

    //--------------------------------------------------------------------------
    // Memory Write Logic (Synchronous) - Clear or Normal Write
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (clearing) begin
            memory[clear_addr] <= {DATA_WIDTH{1'b0}};
        end
        else if (wen) begin
            memory[addr[MEM_ADDR_WIDTH-1:0]] <= wdata;
        end
    end

    //--------------------------------------------------------------------------
    // Memory Read Logic (Synchronous)
    // Blocked during clearing to avoid reading stale data
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (ren && !clearing) begin
            rdata <= memory[addr[MEM_ADDR_WIDTH-1:0]];
        end
    end

    //--------------------------------------------------------------------------
    // Read Valid Generation Logic (async reset)
    // rvalid asserts one cycle after ren assertion (BRAM latency)
    // Blocked during memory clearing
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rvalid   <= 1'b0;
            ren_prev <= 1'b0;
        end
        else if (clearing) begin
            rvalid   <= 1'b0;
            ren_prev <= 1'b0;
        end
        else begin
            // rvalid goes high one cycle after ren is asserted
            if ((!ren_prev) && ren) begin
                rvalid <= 1'b0;  // First cycle of read, data not ready
            end
            else if (ren) begin
                rvalid <= 1'b1;  // Second cycle of read, data is valid
            end
            else begin
                rvalid <= 1'b0;  // No read operation
            end
            
            ren_prev <= ren;
        end
    end

    //--------------------------------------------------------------------------
    // Simulation Memory Initialization
    //--------------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            memory[i] = {DATA_WIDTH{1'b0}};
        end
    end

endmodule
