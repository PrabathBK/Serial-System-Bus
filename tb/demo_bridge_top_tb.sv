//==============================================================================
// File: demo_bridge_top_tb.sv
// Description: Testbench for Demo Bridge Top module
//              Tests bus bridge integration between two bus systems
//==============================================================================

`timescale 1ns / 1ps

module demo_bridge_top_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD = 20;  // 50 MHz
    parameter UART_CLOCKS_PER_PULSE = 5208;
    parameter UART_BIT_PERIOD = CLK_PERIOD * UART_CLOCKS_PER_PULSE;
    
    //==========================================================================
    // DUT Signals
    //==========================================================================
    reg         clk;
    reg  [1:0]  key;
    reg  [3:0]  sw;
    wire [7:0]  led;
    
    // Bus Bridge UART signals
    wire        bridge_m_tx;
    reg         bridge_m_rx;
    wire        bridge_s_tx;
    reg         bridge_s_rx;
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    demo_bridge_top dut (
        .CLOCK_50(clk),
        .KEY(key),
        .SW(sw),
        .LED(led),
        .GPIO_0_BRIDGE_M_TX(bridge_m_tx),
        .GPIO_0_BRIDGE_M_RX(bridge_m_rx),
        .GPIO_0_BRIDGE_S_TX(bridge_s_tx),
        .GPIO_0_BRIDGE_S_RX(bridge_s_rx)
    );
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // UART Loopback for Testing
    //==========================================================================
    // For initial testing, loop back the bridge UART signals
    // Bridge Master TX -> Bridge Slave RX (simulates external bus response)
    // Bridge Slave TX -> Bridge Master RX (simulates external bus command)
    
    // Simple loopback with delay
    reg [7:0] loopback_delay_m;
    reg [7:0] loopback_delay_s;
    
    always @(posedge clk) begin
        loopback_delay_m <= {loopback_delay_m[6:0], bridge_s_tx};
        loopback_delay_s <= {loopback_delay_s[6:0], bridge_m_tx};
    end
    
    // For now, tie RX to idle (high)
    initial begin
        bridge_m_rx = 1'b1;
        bridge_s_rx = 1'b1;
    end
    
    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Initialize
        key = 2'b11;  // Both buttons released (active low)
        sw = 4'b0000; // Reset off, Master 1, Slave 1, Write mode
        
        // Wait for reset
        #100;
        
        // Apply reset via SW[0]
        sw[0] = 1'b1;  // Assert reset
        #200;
        sw[0] = 1'b0;  // Release reset
        #200;
        
        $display("==============================================");
        $display("Test 1: Local Master 1 -> Local Slave 1 Write");
        $display("==============================================");
        
        // Configure: Master 1, Slave 1, Write
        sw = 4'b0000;
        #100;
        
        // Press KEY0 to trigger transaction
        key[0] = 1'b0;  // Press
        #(CLK_PERIOD * 10);
        key[0] = 1'b1;  // Release
        
        // Wait for transaction to complete
        #(CLK_PERIOD * 3000);
        
        $display("LED Status: %b", led);
        $display("  Slave Select: %d", led[1:0]);
        $display("  Data Pattern: %02h", {2'b00, led[7:2]});
        
        $display("==============================================");
        $display("Test 2: Local Master 1 -> Local Slave 2 Write");
        $display("==============================================");
        
        // Increment data pattern
        key[1] = 1'b0;  // Press KEY1
        #(CLK_PERIOD * 10);
        key[1] = 1'b1;  // Release
        #100;
        
        // Configure: Master 1, Slave 2, Write
        sw = 4'b0100;  // SW[2]=1 for Slave 2
        #100;
        
        // Trigger transaction
        key[0] = 1'b0;
        #(CLK_PERIOD * 10);
        key[0] = 1'b1;
        
        #(CLK_PERIOD * 3000);
        
        $display("LED Status: %b", led);
        $display("  Slave Select: %d", led[1:0]);
        $display("  Data Pattern: %02h", {2'b00, led[7:2]});
        
        $display("==============================================");
        $display("Test 3: Local Master 1 -> Bridge Slave 3 Write");
        $display("==============================================");
        
        // Increment data pattern again
        key[1] = 1'b0;
        #(CLK_PERIOD * 10);
        key[1] = 1'b1;
        #100;
        
        // Configure: Master 1, Slave 3 (Bridge), Write
        sw = 4'b1000;  // SW[3:2]=10 for Slave 3
        #100;
        
        // Trigger transaction
        key[0] = 1'b0;
        #(CLK_PERIOD * 10);
        key[0] = 1'b1;
        
        // Wait longer for UART transaction
        #(UART_BIT_PERIOD * 30);
        
        $display("LED Status: %b", led);
        $display("  Slave Select: %d", led[1:0]);
        $display("  Data Pattern: %02h", {2'b00, led[7:2]});
        
        $display("==============================================");
        $display("Test 4: Read back from Slave 1");
        $display("==============================================");
        
        // Configure: Master 1, Slave 1, Read mode
        sw = 4'b1100;  // SW[3:2]=11 for Read mode from Slave 1
        #100;
        
        // Trigger transaction
        key[0] = 1'b0;
        #(CLK_PERIOD * 10);
        key[0] = 1'b1;
        
        #(CLK_PERIOD * 3000);
        
        $display("LED Status: %b", led);
        $display("  Slave Select: %d", led[1:0]);
        $display("  Read Data: %02h", {2'b00, led[7:2]});
        
        $display("==============================================");
        $display("All tests completed!");
        $display("==============================================");
        
        #1000;
        $finish;
    end
    
    //==========================================================================
    // Monitor UART activity
    //==========================================================================
    always @(negedge bridge_m_tx) begin
        $display("[%0t] Bridge Master TX started transmission", $time);
    end
    
    always @(negedge bridge_s_tx) begin
        $display("[%0t] Bridge Slave TX started transmission", $time);
    end

endmodule
