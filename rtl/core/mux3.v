//==============================================================================
// Module: mux3
// Description: Parameterized 3-to-1 multiplexer for slave response routing
// Parameters:
//   WIDTH - Data width (default: 1)
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================

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

    always @(*) begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            default: out = in0;
        endcase
    end

endmodule
