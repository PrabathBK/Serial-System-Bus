/*******************************************************************************
 * Module: dec3
 * Description: 3-output decoder for slave selection
 * 
 * This module decodes a 2-bit selector signal into 3 one-hot outputs.
 * The outputs are enabled only when the enable signal is high.
 * 
 * Date: 2025-10-14
 * Target: Intel Cyclone V (DE10-Nano)
 ******************************************************************************/


`timescale 1ns / 1ps

module dec3 (
    input  wire [1:0] sel,     // 2-bit selector input
    input  wire       en,      // Enable signal
    output wire       out1,    // Output 1 (sel == 2'b00)
    output wire       out2,    // Output 2 (sel == 2'b01)
    output wire       out3     // Output 3 (sel == 2'b10)
);

    // Combinational output logic
    assign out1 = en && (sel == 2'b00);
    assign out2 = en && (sel == 2'b01);
    assign out3 = en && (sel == 2'b10);

endmodule
