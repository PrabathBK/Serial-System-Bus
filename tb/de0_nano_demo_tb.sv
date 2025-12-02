//==============================================================================
// File: de0_nano_demo_tb.sv
// Description: Testbench for DE0-Nano Demo Top Module
//              Simulates button presses and switch changes
// Date: 2025-12-02
//==============================================================================

`timescale 1ns/1ps

module de0_nano_demo_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter CLK_PERIOD = 20;  // 50 MHz = 20ns period
    
    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    reg         CLOCK_50;
    reg  [1:0]  KEY;
    reg  [3:0]  SW;
    wire [7:0]  LED;
    
    // UART signals (directly tied for internal loopback or connected to other DUT)
    wire        GPIO_0_BRIDGE_M_TX;
    reg         GPIO_0_BRIDGE_M_RX;
    wire        GPIO_0_BRIDGE_S_TX;
    reg         GPIO_0_BRIDGE_S_RX;
    
    //--------------------------------------------------------------------------
    // DUT Instantiation
    //--------------------------------------------------------------------------
    de0_nano_demo_top dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .LED(LED),
        .GPIO_0_BRIDGE_M_RX(GPIO_0_BRIDGE_M_RX),
        .GPIO_0_BRIDGE_M_TX(GPIO_0_BRIDGE_M_TX),
        .GPIO_0_BRIDGE_S_RX(GPIO_0_BRIDGE_S_RX),
        .GPIO_0_BRIDGE_S_TX(GPIO_0_BRIDGE_S_TX)
    );
    
    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        CLOCK_50 = 0;
        forever #(CLK_PERIOD/2) CLOCK_50 = ~CLOCK_50;
    end
    
    //--------------------------------------------------------------------------
    // UART Loopback (for simple testing)
    // Bridge Slave TX -> Bridge Master RX (loopback)
    //--------------------------------------------------------------------------
    initial begin
        GPIO_0_BRIDGE_M_RX = 1'b1;  // UART idle high
        GPIO_0_BRIDGE_S_RX = 1'b1;  // UART idle high
    end
    
    //--------------------------------------------------------------------------
    // Task: Press and Release Button
    //--------------------------------------------------------------------------
    task press_key;
        input integer key_num;
        begin
            $display("[%0t] Pressing KEY[%0d]...", $time, key_num);
            KEY[key_num] = 1'b0;  // Press (active low)
            repeat(100) @(posedge CLOCK_50);
            KEY[key_num] = 1'b1;  // Release
            $display("[%0t] Released KEY[%0d]", $time, key_num);
            repeat(10) @(posedge CLOCK_50);
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Task: Wait for transaction to complete
    //--------------------------------------------------------------------------
    task wait_for_idle;
        begin
            $display("[%0t] Waiting for transaction to complete...", $time);
            repeat(2000) @(posedge CLOCK_50);
            $display("[%0t] Wait complete. LED = 0x%02h", $time, LED);
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Main Test Sequence
    //--------------------------------------------------------------------------
    initial begin
        // Waveform dump
        $dumpfile("de0_nano_demo_tb.vcd");
        $dumpvars(0, de0_nano_demo_tb);
        
        $display("============================================================");
        $display("   DE0-Nano Demo Testbench Started");
        $display("============================================================");
        
        // Initialize
        KEY = 2'b11;  // Both buttons released (active low)
        SW = 4'b0000;
        
        // Wait for initial setup
        repeat(10) @(posedge CLOCK_50);
        
        //======================================================================
        // Test 1: Reset the system
        //======================================================================
        $display("\n--- Test 1: System Reset ---");
        press_key(0);  // Press KEY[0] for reset
        wait_for_idle();
        
        //======================================================================
        // Test 2: Write to Slave 1
        //======================================================================
        $display("\n--- Test 2: Write to Slave 1 (SW[3:2]=00) ---");
        SW = 4'b0001;  // Mode=00 (write Slave1), Data=01
        repeat(10) @(posedge CLOCK_50);
        press_key(1);  // Execute
        wait_for_idle();
        $display("LED after write: 0x%02h", LED);
        
        //======================================================================
        // Test 3: Read from Slave 1
        //======================================================================
        $display("\n--- Test 3: Read from Slave 1 (SW[3:2]=11) ---");
        SW = 4'b1100;  // Mode=11 (read)
        repeat(10) @(posedge CLOCK_50);
        press_key(1);  // Execute
        wait_for_idle();
        $display("LED after read: 0x%02h (expected: data written earlier)", LED);
        
        //======================================================================
        // Test 4: Write to Slave 2
        //======================================================================
        $display("\n--- Test 4: Write to Slave 2 (SW[3:2]=01) ---");
        SW = 4'b0110;  // Mode=01 (write Slave2), Data=10
        repeat(10) @(posedge CLOCK_50);
        press_key(1);  // Execute
        wait_for_idle();
        $display("LED after write: 0x%02h", LED);
        
        //======================================================================
        // Test 5: Read from Slave 2
        //======================================================================
        $display("\n--- Test 5: Read from Slave 2 (SW[3:2]=11) ---");
        SW = 4'b1100;  // Mode=11 (read from last written = Slave2)
        repeat(10) @(posedge CLOCK_50);
        press_key(1);  // Execute
        wait_for_idle();
        $display("LED after read: 0x%02h", LED);
        
        //======================================================================
        // Test 6: Multiple writes with different data
        //======================================================================
        $display("\n--- Test 6: Multiple Writes to Slave 1 ---");
        
        SW = 4'b0000;  // Slave1, data=00
        repeat(10) @(posedge CLOCK_50);
        press_key(1);
        wait_for_idle();
        
        SW = 4'b0011;  // Slave1, data=11
        repeat(10) @(posedge CLOCK_50);
        press_key(1);
        wait_for_idle();
        
        //======================================================================
        // Test 7: Write to Slave 3 (Bus Bridge)
        //======================================================================
        $display("\n--- Test 7: Write to Slave 3 / Bus Bridge (SW[3:2]=10) ---");
        SW = 4'b1001;  // Mode=10 (write to bridge slave), Data=01
        repeat(10) @(posedge CLOCK_50);
        press_key(1);  // Execute
        // Wait longer for UART transmission
        repeat(10000) @(posedge CLOCK_50);
        $display("LED after bridge write: 0x%02h", LED);
        $display("Bridge Slave TX activity expected on GPIO_0_BRIDGE_S_TX");
        
        //======================================================================
        // Summary
        //======================================================================
        $display("\n============================================================");
        $display("   Testbench Complete");
        $display("============================================================");
        $display("Final LED state: 0x%02h", LED);
        $display("");
        
        #1000;
        $finish;
    end
    
    //--------------------------------------------------------------------------
    // Timeout Watchdog
    //--------------------------------------------------------------------------
    initial begin
        #500000;  // 500us timeout
        $display("\n*** TIMEOUT ***");
        $finish;
    end
    
    //--------------------------------------------------------------------------
    // Monitor Key State Changes
    //--------------------------------------------------------------------------
    always @(LED) begin
        $display("[%0t] LED changed: 0x%02h (%08b)", $time, LED, LED);
    end
    
    //--------------------------------------------------------------------------
    // Monitor UART TX Activity
    //--------------------------------------------------------------------------
    reg bridge_s_tx_prev;
    always @(posedge CLOCK_50) begin
        bridge_s_tx_prev <= GPIO_0_BRIDGE_S_TX;
        if (bridge_s_tx_prev != GPIO_0_BRIDGE_S_TX) begin
            $display("[%0t] Bridge Slave UART TX: %b", $time, GPIO_0_BRIDGE_S_TX);
        end
    end

endmodule
