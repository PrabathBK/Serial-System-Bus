//==============================================================================
// File: master.v
// Description: Complete master wrapper module
//              Instantiates master_port and master_memory_bram
//              Provides complete master functionality with local memory
//              
//              The master has both:
//              - An external interface (master_port) to access slaves on the bus
//              - Internal memory (BRAM) that can be accessed by an external device
//                or can be used as local storage
//
// Architecture:
//              +------------------------------------------+
//              |                master.v                  |
//              |  +----------------+   +---------------+  |
//              |  |  master_port   |   | master_memory |  |
//              |  |                |   |    _bram      |  |
//              |  |  (bus access)  |   | (local store) |  |
//              |  +----------------+   +---------------+  |
//              |        |                    |            |
//              +--------|--------------------|-----------+
//                       |                    |
//                   to serial bus      device interface
//
//==============================================================================
// Author: ADS Bus System
// Date: 2025-12-02
//==============================================================================

`timescale 1ns / 1ps

module master #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter SLAVE_MEM_ADDR_WIDTH = 12,
    parameter LOCAL_MEM_ADDR_WIDTH = 12,
    parameter LOCAL_MEM_SIZE = 4096      // Local memory size in bytes
)(
    // Global signals
    input  wire                     clk,
    input  wire                     rstn,
    
    //--------------------------------------------------------------------------
    // Device Interface - External device commands master to perform bus transactions
    //--------------------------------------------------------------------------
    input  wire [DATA_WIDTH-1:0]    dwdata,      // Write data from device
    output wire [DATA_WIDTH-1:0]    drdata,      // Read data to device
    input  wire [ADDR_WIDTH-1:0]    daddr,       // Address from device
    input  wire                     dvalid,      // Transaction request valid
    output wire                     dready,      // Master ready for new transaction
    input  wire                     dmode,       // 0 - read, 1 - write
    
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
    // Serial Bus Interface
    //--------------------------------------------------------------------------
    input  wire                     mrdata,      // Read data from bus (serial)
    output wire                     mwdata,      // Write data/address to bus (serial)
    output wire                     mmode,       // 0 - read, 1 - write
    output wire                     mvalid,      // Write data valid
    input  wire                     svalid,      // Read data valid from slave
    
    //--------------------------------------------------------------------------
    // Arbiter Interface
    //--------------------------------------------------------------------------
    output wire                     mbreq,       // Bus request
    input  wire                     mbgrant,     // Bus grant
    input  wire                     msplit,      // Split signal
    
    //--------------------------------------------------------------------------
    // Address Decoder Interface
    //--------------------------------------------------------------------------
    input  wire                     ack          // Acknowledgement
);

    //--------------------------------------------------------------------------
    // Master Port Instantiation - Handles bus protocol
    //--------------------------------------------------------------------------
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE_MEM_ADDR_WIDTH)
    ) mp (
        // Global signals
        .clk(clk),
        .rstn(rstn),
        
        // Device interface
        .dwdata(dwdata),
        .drdata(drdata),
        .daddr(daddr),
        .dvalid(dvalid),
        .dready(dready),
        .dmode(dmode),
        
        // Serial bus interface
        .mrdata(mrdata),
        .mwdata(mwdata),
        .mmode(mmode),
        .mvalid(mvalid),
        .svalid(svalid),
        
        // Arbiter interface
        .mbreq(mbreq),
        .mbgrant(mbgrant),
        .msplit(msplit),
        
        // Address decoder interface
        .ack(ack)
    );

    //--------------------------------------------------------------------------
    // Master Local Memory BRAM Instantiation
    //--------------------------------------------------------------------------
    master_memory_bram #(
        .ADDR_WIDTH(LOCAL_MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_SIZE(LOCAL_MEM_SIZE)
    ) mm (
        // Global signals
        .clk(clk),
        .rstn(rstn),
        
        // Memory interface
        .wen(lmem_wen),
        .ren(lmem_ren),
        .addr(lmem_addr),
        .wdata(lmem_wdata),
        .rdata(lmem_rdata),
        .rvalid(lmem_rvalid)
    );

endmodule
