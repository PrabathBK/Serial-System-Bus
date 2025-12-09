//==============================================================================
// File: uart_to_other_team_rx_adapter.v
// Description: Protocol adapter to convert other team's 2-byte sequence to
//              ADS 8-bit UART frame format
//
//              Input: 2-byte sequence from their UART
//                Byte 0: data[7:0] (read data)
//                Byte 1: {7'b0, is_write[0]} (flags)
//              Output: 8-bit data frame for ADS bus bridge
//
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================
// Author: ADS Bus System - Adapter Module
// Date: 2025-12-09
//==============================================================================

`timescale 1ns / 1ps

module uart_to_other_team_rx_adapter (
    input  wire        clk,
    input  wire        rstn,
    
    //--------------------------------------------------------------------------
    // Input from Other Team's UART (their uart.v interface)
    //--------------------------------------------------------------------------
    input  wire [7:0]  uart_data_out,   // Received data
    input  wire        uart_ready,      // Data ready signal
    output reg         uart_ready_clr,  // Clear ready signal
    
    //--------------------------------------------------------------------------
    // Output to ADS Bus Bridge (8-bit data interface)
    //--------------------------------------------------------------------------
    output reg  [7:0]  frame_out,       // Output data (8 bits)
    output reg         frame_valid,     // Frame ready
    input  wire        frame_ready,     // Bridge ready to accept
    input  wire        clk_50m          // Their clock (50MHz)
);

    //==========================================================================
    // State Machine
    //==========================================================================
    localparam IDLE          = 2'd0;
    localparam WAIT_FLAGS    = 2'd1;
    localparam OUTPUT_FRAME  = 2'd2;
    
    reg [1:0] state;
    
    //==========================================================================
    // Frame Assembly
    //==========================================================================
    reg [7:0] data_byte;         // Captured data byte (Byte 0)
    reg       is_write_flag;     // Captured write flag (Byte 1, bit 0)
    
    //==========================================================================
    // Ready Detection - Edge detector for uart_ready
    //==========================================================================
    reg uart_ready_d;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            uart_ready_d <= 1'b0;
        else
            uart_ready_d <= uart_ready;
    end
    
    // Detect rising edge of uart_ready (new byte received)
    wire uart_ready_pulse;
    assign uart_ready_pulse = uart_ready && !uart_ready_d;
    
    //==========================================================================
    // Main FSM
    //==========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            data_byte <= 8'h00;
            is_write_flag <= 1'b0;
            frame_out <= 8'h00;
            frame_valid <= 1'b0;
            uart_ready_clr <= 1'b0;
        end else begin
            // Default: deassert ready_clr  
            uart_ready_clr <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                // IDLE: Wait for first byte (data)
                //--------------------------------------------------------------
                IDLE: begin
                    frame_valid <= 1'b0;
                    if (uart_ready && !uart_ready_clr) begin
                        // Capture Byte 0: read data
                        data_byte <= uart_data_out;
                        uart_ready_clr <= 1'b1;
                        state <= WAIT_FLAGS;
                    end
                end
                
                //--------------------------------------------------------------
                // WAIT_FLAGS: Wait for second byte (flags)
                //--------------------------------------------------------------
                WAIT_FLAGS: begin
                    if (uart_ready && !uart_ready_clr) begin
                        // Capture Byte 1: flags (only bit 0 is used for is_write)
                        is_write_flag <= uart_data_out[0];
                        uart_ready_clr <= 1'b1;
                        
                        // Assemble output frame
                        // For read responses, we only care about the data byte
                        frame_out <= data_byte;
                        frame_valid <= 1'b1;
                        state <= OUTPUT_FRAME;
                    end
                end
                
                //--------------------------------------------------------------
                // OUTPUT_FRAME: Hold frame valid until accepted
                //--------------------------------------------------------------
                OUTPUT_FRAME: begin
                    if (frame_ready) begin
                        // Frame accepted by ADS bus bridge
                        frame_valid <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
