//==============================================================================
// File: uart_to_other_team_tx_adapter.v
// Description: Protocol adapter to convert ADS 21-bit UART frames to other 
//              team's 4-byte sequence format at 115200 baud
//
//              Input: 21-bit frame {mode[0], addr[11:0], data[7:0]}
//              Output: 4-byte sequence for their UART
//                Byte 0: addr[7:0] (LSB)
//                Byte 1: addr[15:8] (MSB, upper 4 bits padded with 0)
//                Byte 2: data[7:0]
//                Byte 3: {7'b0, mode[0]} (is_write flag)
//
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================
// Author: ADS Bus System - Adapter Module
// Date: 2025-12-09
//==============================================================================

`timescale 1ns / 1ps

module uart_to_other_team_tx_adapter (
    input  wire        clk,
    input  wire        rstn,
    
    //--------------------------------------------------------------------------
    // Input from ADS Bus Bridge (21-bit frame interface)
    //--------------------------------------------------------------------------
    input  wire [20:0] frame_in,        // {mode[0], addr[11:0], data[7:0]}
    input  wire        frame_valid,     // Frame available
    output reg         frame_ready,     // Ready to accept new frame
    
    //--------------------------------------------------------------------------
    // Output to Other Team's UART (their uart.v interface)
    //--------------------------------------------------------------------------
    output reg  [7:0]  uart_data_in,    // Data to send
    output reg         uart_wr_en,      // Write enable
    input  wire        uart_tx_busy,    // UART busy signal
    input  wire        clk_50m          // Their clock (50MHz)
);

    //==========================================================================
    // State Machine
    //==========================================================================
    localparam IDLE         = 3'd0;
    localparam SEND_ADDR_L  = 3'd1;
    localparam WAIT_ADDR_L  = 3'd2;
    localparam SEND_ADDR_H  = 3'd3;
    localparam WAIT_ADDR_H  = 3'd4;
    localparam SEND_DATA    = 3'd5;
    localparam WAIT_DATA    = 3'd6;
    localparam SEND_FLAGS   = 3'd7;
    localparam WAIT_FLAGS   = 3'd8;
    
    reg [2:0] state;
    
    //==========================================================================
    // Frame Storage
    //==========================================================================
    reg [20:0] frame_buf;       // Buffer for incoming frame
    reg        frame_captured;  // Frame has been captured
    
    // Extract fields from frame: {mode[0], addr[11:0], data[7:0]}
    wire       mode_bit;
    wire [11:0] addr_12bit;
    wire [7:0]  data_byte;
    
    assign mode_bit   = frame_buf[20];
    assign addr_12bit = frame_buf[19:8];
    assign data_byte  = frame_buf[7:0];
    
    //==========================================================================
    // Busy Detection
    //==========================================================================
    reg uart_tx_busy_d;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            uart_tx_busy_d <= 1'b0;
        else
            uart_tx_busy_d <= uart_tx_busy;
    end
    
    // Detect falling edge of uart_tx_busy (transmission complete)
    wire uart_tx_done;
    assign uart_tx_done = uart_tx_busy_d && !uart_tx_busy;
    
    //==========================================================================
    // Main FSM
    //==========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            frame_buf <= 21'h0;
            frame_captured <= 1'b0;
            frame_ready <= 1'b1;
            uart_data_in <= 8'h00;
            uart_wr_en <= 1'b0;
        end else begin
            // Default: deassert write enable
            uart_wr_en <= 1'b0;
            
            case (state)
                IDLE: begin
                    frame_ready <= 1'b1;
                    if (frame_valid && frame_ready) begin
                        // Capture incoming frame
                        frame_buf <= frame_in;
                        frame_captured <= 1'b1;
                        frame_ready <= 1'b0;
                        state <= SEND_ADDR_L;
                    end
                end
                
                //--------------------------------------------------------------
                // Send Address LSB (Byte 0)
                //--------------------------------------------------------------
                SEND_ADDR_L: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= addr_12bit[7:0];  // Address bits [7:0]
                        uart_wr_en <= 1'b1;
                        state <= WAIT_ADDR_L;
                    end
                end
                
                WAIT_ADDR_L: begin
                    if (uart_tx_done) begin
                        state <= SEND_ADDR_H;
                    end
                end
                
                //--------------------------------------------------------------
                // Send Address MSB (Byte 1) - pad upper 4 bits with zeros
                //--------------------------------------------------------------
                SEND_ADDR_H: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= {4'b0000, addr_12bit[11:8]};  // Pad to 16-bit addr
                        uart_wr_en <= 1'b1;
                        state <= WAIT_ADDR_H;
                    end
                end
                
                WAIT_ADDR_H: begin
                    if (uart_tx_done) begin
                        state <= SEND_DATA;
                    end
                end
                
                //--------------------------------------------------------------
                // Send Data Byte (Byte 2)
                //--------------------------------------------------------------
                SEND_DATA: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= data_byte;
                        uart_wr_en <= 1'b1;
                        state <= WAIT_DATA;
                    end
                end
                
                WAIT_DATA: begin
                    if (uart_tx_done) begin
                        state <= SEND_FLAGS;
                    end
                end
                
                //--------------------------------------------------------------
                // Send Flags (Byte 3) - bit 0 is write flag
                //--------------------------------------------------------------
                SEND_FLAGS: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= {7'b0000000, mode_bit};  // is_write in bit 0
                        uart_wr_en <= 1'b1;
                        state <= WAIT_FLAGS;
                    end
                end
                
                WAIT_FLAGS: begin
                    if (uart_tx_done) begin
                        frame_captured <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
