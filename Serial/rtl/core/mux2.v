//-----------------------------------------------------------------------------
// Module: mux2
// Description: Parameterized 2-to-1 Multiplexer
//              Generic multiplexer for data path selection
//
// Parameters:
//   WIDTH - Data width (default: 1)
//
// Inputs:
//   in0   - Input 0 [WIDTH-1:0]
//   in1   - Input 1 [WIDTH-1:0]
//   sel   - Select signal (0: in0, 1: in1)
//
// Outputs:
//   out   - Selected output [WIDTH-1:0]
//
// Author: ADS Bus System Generator
// Target: Intel Cyclone V (Terasic DE10-Nano)
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps

module mux2 #(
    parameter WIDTH = 1
)(
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    input  wire             sel,
    output wire [WIDTH-1:0] out
);

    // Combinational multiplexer
    assign out = sel ? in1 : in0;

endmodule
