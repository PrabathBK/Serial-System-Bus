//==============================================================================
// File: slave.v
// Description: Complete slave wrapper module
//              Instantiates slave_port and slave_memory_bram
//              Provides complete slave functionality with configurable SPLIT
//==============================================================================
// Author: ADS Bus System
// Date: 2025-10-14
//==============================================================================


`timescale 1ns / 1ps

module slave #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 8,
    parameter SPLIT_EN = 0,        // Enable split transaction support (0 or 1)
    parameter MEM_SIZE = 4096      // Memory size in bytes (2048 or 4096)
)(
    // Global signals
    input  wire                     clk,
    input  wire                     rstn,
    
    // Signals connecting to serial bus
    input  wire                     swdata,      // Write data and address from master
    output wire                     srdata,      // Read data to the master
    input  wire                     smode,       // 0 - read, 1 - write
    input  wire                     mvalid,      // Indicates receiving data and address from master
    input  wire                     split_grant, // Grant bus access in split transaction
    output wire                     svalid,      // Indicates read data is transmitting
    output wire                     sready,      // Slave is ready for transaction
    output wire                     ssplit       // Split transaction signal
);

    //--------------------------------------------------------------------------
    // Internal Signals - Connecting Slave Port to Memory
    //--------------------------------------------------------------------------
    wire [DATA_WIDTH-1:0]    smemrdata;    // Data read from slave memory
    wire                     smemwen;      // Write enable to slave memory
    wire                     smemren;      // Read enable to slave memory
    wire [ADDR_WIDTH-1:0]    smemaddr;     // Address to slave memory
    wire [DATA_WIDTH-1:0]    smemwdata;    // Data written to slave memory
    wire                     rvalid;       // Read data valid from memory

    //--------------------------------------------------------------------------
    // Slave Port Instantiation
    //--------------------------------------------------------------------------
    slave_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(SPLIT_EN)
    ) sp (
        // Global signals
        .clk(clk),
        .rstn(rstn),
        
        // Signals to/from slave memory
        .smemrdata(smemrdata),
        .rvalid(rvalid),
        .smemwen(smemwen),
        .smemren(smemren),
        .smemaddr(smemaddr),
        .smemwdata(smemwdata),
        
        // Signals to/from serial bus
        .swdata(swdata),
        .srdata(srdata),
        .smode(smode),
        .mvalid(mvalid),
        .split_grant(split_grant),
        .svalid(svalid),
        .sready(sready),
        .ssplit(ssplit)
    );

    //--------------------------------------------------------------------------
    // Slave Memory BRAM Instantiation
    //--------------------------------------------------------------------------
    slave_memory_bram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) sm (
        // Global signals
        .clk(clk),
        .rstn(rstn),
        
        // Memory interface
        .wen(smemwen),
        .ren(smemren),
        .addr(smemaddr),
        .wdata(smemwdata),
        .rdata(smemrdata),
        .rvalid(rvalid)
    );

endmodule
