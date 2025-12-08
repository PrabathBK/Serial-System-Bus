//==============================================================================
// Module: dec3
// Description: 3-output decoder for slave selection. Decodes 2-bit selector
//              into 3 one-hot outputs, active only when enable is high.
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================

`timescale 1ns / 1ps

module dec3 (
    input  wire [1:0] sel,
    input  wire       en,
    output wire       out1,
    output wire       out2,
    output wire       out3
);

    assign out1 = en && (sel == 2'b00);
    assign out2 = en && (sel == 2'b01);
    assign out3 = en && (sel == 2'b10);

endmodule
