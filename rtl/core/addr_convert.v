`timescale 1ns/1ps

//==============================================================================
// Module: addr_convert
// Description: Converts bridge address to local bus address
//              
// Bridge Address Format (BB_ADDR_WIDTH=12 bits):
//   bit 11:    Bridge indicator (must be 1 for bridge access)
//   bit 10:    Remote slave select (0=Slave1, 1=Slave2)
//   bits 9:0:  Memory address within slave
//
// Bus Address Output (BUS_ADDR_WIDTH=16 bits):
//   bits 15:12: Device address (0=Slave1, 1=Slave2)
//   bits 11:0:  Memory address
//==============================================================================

module addr_convert #(
    parameter BB_ADDR_WIDTH = 12,
    parameter BUS_ADDR_WIDTH = 16,
    parameter BUS_MEM_ADDR_WIDTH = 12
) (
    input [BB_ADDR_WIDTH-1:0] bb_addr,
    output [BUS_ADDR_WIDTH-1:0] bus_addr
);

    // Memory address: bits [9:0] of bridge address, zero-padded to 12 bits
    assign bus_addr[(BUS_MEM_ADDR_WIDTH-1):0] = {{(BUS_MEM_ADDR_WIDTH-10){1'b0}}, bb_addr[9:0]};
    
    // Device select: bit 10 of bridge address -> bit 12 of bus address
    // 0 = Slave 1 (device addr 0x0xxx), 1 = Slave 2 (device addr 0x1xxx)
    assign bus_addr[12] = bb_addr[10];
    
    // Upper bits of device address are always 0
    assign bus_addr[BUS_ADDR_WIDTH-1:13] = 'b0;

endmodule