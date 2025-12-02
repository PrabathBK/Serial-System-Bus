//==============================================================================
// File: master_memory_bram.v
// Description: Master memory module with BRAM instantiation
//              Provides local storage for master devices
//              Can be accessed by the master's internal logic
//==============================================================================
// Author: ADS Bus System
// Date: 2025-12-02
//==============================================================================

`timescale 1ns / 1ps

module master_memory_bram #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 8,
    parameter MEM_SIZE = 4096  // Memory size in bytes (default 4KB)
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

    //--------------------------------------------------------------------------
    // Memory Array Declaration
    //--------------------------------------------------------------------------
    // Behavioral memory for simulation and synthesis
    // Will be inferred as M10K blocks by Quartus for Cyclone V
    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];

    //--------------------------------------------------------------------------
    // Memory Write Logic (Synchronous)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (wen) begin
            memory[addr[MEM_ADDR_WIDTH-1:0]] <= wdata;
            $display("[MASTER_MEMORY @%0t] Write: addr=0x%h, data=0x%h", 
                     $time, addr[MEM_ADDR_WIDTH-1:0], wdata);
        end
    end

    //--------------------------------------------------------------------------
    // Memory Read Logic (Synchronous)
    // Note: No reset on rdata to allow M10K block RAM inference
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (ren) begin
            rdata <= memory[addr[MEM_ADDR_WIDTH-1:0]];
            $display("[MASTER_MEMORY @%0t] Read: addr=0x%h, data=0x%h", 
                     $time, addr[MEM_ADDR_WIDTH-1:0], memory[addr[MEM_ADDR_WIDTH-1:0]]);
        end
    end

    //--------------------------------------------------------------------------
    // Read Valid Generation Logic
    // rvalid asserts one cycle after ren assertion (BRAM latency)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
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
    // Simulation Memory Initialization (Optional)
    //--------------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            memory[i] = {DATA_WIDTH{1'b0}};
        end
    end

endmodule
