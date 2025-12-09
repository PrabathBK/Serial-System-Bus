//==============================================================================
// Module: mux2
// Description: Parameterized 2-to-1 multiplexer for data path selection
// Parameters:
//   WIDTH - Data width (default: 1)
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================

`timescale 1ns / 1ps

module mux2 #(
    parameter WIDTH = 1
)(
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    input  wire             sel,
    output wire [WIDTH-1:0] out
);

    assign out = sel ? in1 : in0;

endmodule
