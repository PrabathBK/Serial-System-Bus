//-----------------------------------------------------------------------------
// Module: mux3
// Description: Parameterized 3-to-1 Multiplexer
//              Used for slave response multiplexing in bus system
//
// Parameters:
//   WIDTH - Data width (default: 1)
//
// Inputs:
//   in0   - Input 0 [WIDTH-1:0]
//   in1   - Input 1 [WIDTH-1:0]
//   in2   - Input 2 [WIDTH-1:0]
//   sel   - Select signal [1:0] (2'b00: in0, 2'b01: in1, 2'b10: in2)
//
// Outputs:
//   out   - Selected output [WIDTH-1:0]
//
// Author: ADS Bus System Generator
// Target: Intel Cyclone V (Terasic DE10-Nano)
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps

module mux3 #(
    parameter WIDTH = 1
)(
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    input  wire [WIDTH-1:0] in2,
    input  wire [1:0]       sel,
    output reg  [WIDTH-1:0] out
);

    // Combinational multiplexer
    always @(*) begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            default: out = in0;  // Default to in0
        endcase
    end

endmodule
