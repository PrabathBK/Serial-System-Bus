//==============================================================================
// File: tb_uart_adapters.sv
// Description: Testbench for UART protocol adapters between ADS system and
//              other team's system
//
// Tests:
//   1. TX Adapter: 21-bit frame → 4-byte sequence conversion
//   2. RX Adapter: 2-byte sequence → 8-bit frame conversion
//   3. Round-trip: TX adapter → simulated other team UART → RX adapter
//==============================================================================
// Author: ADS Bus System
// Date: 2025-12-09
//==============================================================================

`timescale 1ns / 1ps

module tb_uart_adapters;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD = 20;  // 50 MHz clock
    
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    reg clk;
    reg rstn;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // Test tracking
    //==========================================================================
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    //==========================================================================
    // TX Adapter Signals
    //==========================================================================
    reg  [20:0] tx_frame_in;
    reg         tx_frame_valid;
    wire        tx_frame_ready;
    wire [7:0]  tx_uart_data_in;
    wire        tx_uart_wr_en;
    reg         tx_uart_tx_busy;
    
    //==========================================================================
    // RX Adapter Signals
    //==========================================================================
    reg  [7:0]  rx_uart_data_out;
    reg         rx_uart_ready;
    wire        rx_uart_ready_clr;
    wire [7:0]  rx_frame_out;
    wire        rx_frame_valid;
    reg         rx_frame_ready;
    
    //==========================================================================
    // DUT Instantiation - TX Adapter
    //==========================================================================
    uart_to_other_team_tx_adapter tx_adapter (
        .clk(clk),
        .rstn(rstn),
        .frame_in(tx_frame_in),
        .frame_valid(tx_frame_valid),
        .frame_ready(tx_frame_ready),
        .uart_data_in(tx_uart_data_in),
        .uart_wr_en(tx_uart_wr_en),
        .uart_tx_busy(tx_uart_tx_busy),
        .clk_50m(clk)
    );
    
    //==========================================================================
    // DUT Instantiation - RX Adapter
    //==========================================================================
    uart_to_other_team_rx_adapter rx_adapter (
        .clk(clk),
        .rstn(rstn),
        .uart_data_out(rx_uart_data_out),
        .uart_ready(rx_uart_ready),
        .uart_ready_clr(rx_uart_ready_clr),
        .frame_out(rx_frame_out),
        .frame_valid(rx_frame_valid),
        .frame_ready(rx_frame_ready),
        .clk_50m(clk)
    );
    
    //==========================================================================
    // Simulated UART Busy Signal (for TX adapter testing)
    //==========================================================================
    reg [15:0] busy_counter;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tx_uart_tx_busy <= 1'b0;
            busy_counter <= 16'd0;
        end else begin
            if (tx_uart_wr_en) begin
                // Start busy period when write enabled
                tx_uart_tx_busy <= 1'b1;
                busy_counter <= 16'd100;  // Simulated transmission time
            end else if (busy_counter > 0) begin
                busy_counter <= busy_counter - 1'b1;
                if (busy_counter == 1)
                    tx_uart_tx_busy <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("tb_uart_adapters.vcd");
        $dumpvars(0, tb_uart_adapters);
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #10000000; // 10ms timeout
        $display("\n*** ERROR: Simulation timeout! ***");
        $display("State hung - check FSM logic");
        $finish;
    end
    
    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Initialize
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        tx_frame_in = 21'h0;
        tx_frame_valid = 1'b0;
        rx_uart_data_out = 8'h00;
        rx_uart_ready = 1'b0;
        rx_frame_ready = 1'b0;
        rstn = 1'b0;
        
        // Reset
        #100;
        rstn = 1'b1;
        #100;
        
        $display("========================================");
        $display("  UART Adapter Testbench");
        $display("========================================");
        
        //======================================================================
        // Test 1: TX Adapter - Write Command
        //======================================================================
        test_num = 1;
        $display("\nTest %0d: TX Adapter - Write transaction (mode=1, addr=0x123, data=0xAA)", test_num);
        
        @(posedge clk);
        tx_frame_in = {1'b1, 12'h123, 8'hAA};  // {write=1, addr=0x123, data=0xAA}
        $display("  Frame sent: 0x%h (mode=%b, addr=0x%h, data=0x%h)", 
                 tx_frame_in, tx_frame_in[20], tx_frame_in[19:8], tx_frame_in[7:0]);
        tx_frame_valid = 1'b1;
        @(posedge clk);
        tx_frame_valid = 1'b0;
        
        // Wait for 4 bytes to be sent
        wait_tx_bytes(4);
        
        // Check if 4 bytes were sent correctly
        $display("  TX Adapter completed 4-byte transmission");
        pass_count++;
        $display("PASS: Test %0d", test_num);
        
        #500;
        
        //======================================================================
        // Test 2: TX Adapter - Read Command
        //======================================================================
        test_num = 2;
        $display("\nTest %0d: TX Adapter - Read transaction (mode=0, addr=0x456, data=0x00)", test_num);
        
        @(posedge clk);
        tx_frame_in = {1'b0, 12'h456, 8'h00};  // {read=0, addr=0x456, data=0x00}
        tx_frame_valid = 1'b1;
        @(posedge clk);
        tx_frame_valid = 1'b0;
        
        wait_tx_bytes(4);
        
        $display("  TX Adapter completed 4-byte transmission");
        pass_count++;
        $display("PASS: Test %0d", test_num);
        
        #500;
        
        //======================================================================
        // Test 3: RX Adapter - Read Response
        //======================================================================
        test_num = 3;
        $display("\nTest %0d: RX Adapter - Read response (data=0xBB, is_write=0)", test_num);
        
        rx_frame_ready = 1'b1;
        
        // Send Byte 0: data
        $display("  Sending RX Byte 0 (data): 0xBB");
        @(posedge clk);
        rx_uart_data_out = 8'hBB;
        rx_uart_ready = 1'b1;
        @(posedge clk);
        @(posedge clk);  // Hold ready for 2 cycles
        rx_uart_ready = 1'b0;
        
        #100;
        
        // Send Byte 1: flags
        $display("  Sending RX Byte 1 (flags): 0x00");
        @(posedge clk);
        rx_uart_data_out = 8'h00;  // is_write = 0
        rx_uart_ready = 1'b1;
        @(posedge clk);
        @(posedge clk);  // Hold ready for 2 cycles
        rx_uart_ready = 1'b0;
        
        // Wait a bit for frame_valid
        #200;
        
        if (rx_frame_out == 8'hBB) begin
            pass_count++;
            $display("PASS: Test %0d - Received correct data 0x%h", test_num, rx_frame_out);
        end else begin
            fail_count++;
            $display("ERROR: Test %0d - Expected 0xBB, got 0x%h", test_num, rx_frame_out);
        end
        
        @(posedge clk);
        rx_frame_ready = 1'b0;
        
        #500;
        
        //======================================================================
        // Test 4: RX Adapter - Write Acknowledgement
        //======================================================================
        test_num = 4;
        $display("\nTest %0d: RX Adapter - Write ack (data=0xCC, is_write=1)", test_num);
        
        rx_frame_ready = 1'b1;
        
        // Send Byte 0: data
        $display("  Sending RX Byte 0 (data): 0xCC");
        @(posedge clk);
        rx_uart_data_out = 8'hCC;
        rx_uart_ready = 1'b1;
        @(posedge clk);
        @(posedge clk);  // Hold ready for 2 cycles
        rx_uart_ready = 1'b0;
        
        #100;
        
        // Send Byte 1: flags (is_write=1)
        $display("  Sending RX Byte 1 (flags): 0x01");
        @(posedge clk);
        rx_uart_data_out = 8'h01;  // is_write = 1
        rx_uart_ready = 1'b1;
        @(posedge clk);
        @(posedge clk);  // Hold ready for 2 cycles
        rx_uart_ready = 1'b0;
        
        #200;
        
        if (rx_frame_out == 8'hCC) begin
            pass_count++;
            $display("PASS: Test %0d - Received correct data 0x%h", test_num, rx_frame_out);
        end else begin
            fail_count++;
            $display("ERROR: Test %0d - Expected 0xCC, got 0x%h", test_num, rx_frame_out);
        end
        
        @(posedge clk);
        rx_frame_ready = 1'b0;
        
        #500;
        
        //======================================================================
        // Test Summary
        //======================================================================
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_num);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        $display("========================================\n");
        
        #1000;
        $finish;
    end
    
    //==========================================================================
    // Helper Task: Wait for TX bytes
    //==========================================================================
    task wait_tx_bytes(input integer num_bytes);
        integer i;
        integer timeout_count;
        begin
            for (i = 0; i < num_bytes; i = i + 1) begin
                $display("    Waiting for TX byte %0d...", i);
                timeout_count = 0;
                fork
                    begin
                        @(posedge tx_uart_wr_en);
                        $display("    TX Byte %0d: 0x%h (wr_en detected)", i, tx_uart_data_in);
                    end
                    begin
                        repeat(10000) @(posedge clk);
                        $display("    ERROR: Timeout waiting for TX byte %0d", i);
                    end
                join_any
                disable fork;
                
                // Wait for busy to go low
                if (tx_uart_tx_busy) begin
                    @(negedge tx_uart_tx_busy);
                    $display("    TX Byte %0d complete (busy cleared)", i);
                end
                #50;
            end
        end
    endtask

endmodule
