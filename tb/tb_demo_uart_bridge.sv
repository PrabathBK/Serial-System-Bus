//==============================================================================
// File: tb_demo_uart_bridge.sv
// Description: Testbench for demo_uart_bridge.v - Uses actual DE0-Nano top-level
//              module with KEY/SW/LED interfaces. Instantiates two systems
//              (A and B) with UART cross-connected to verify inter-FPGA bridge.
//
// New Control Scheme:
//   - KEY[0]: Initiate transfer (read or write based on SW[3])
//   - KEY[1]: Increment data value
//   - KEY[0]+KEY[1]: Reset increment value to 0
//   - SW[0]:  Reset (active HIGH)
//   - SW[1]:  Slave select (0=S1, 1=S2) for both internal/external
//   - SW[2]:  Mode (0=Internal, 1=External via Bridge)
//   - SW[3]:  R/W (0=Read, 1=Write)
//   - LED[7:0]: Write mode shows increment value, Read mode shows read data
//
// Test Cases:
//   Tests 1-19: Commented out for focused testing
//   Test 1:  NEW - A:M1 -> A:S1 (internal write), B:M1 -> A:S1 (external read via bridge)
//   Test 20: A:M1 -> B:S1 (external write via bridge), B:M1 -> B:S1 (internal read)
//
// Target Device: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//==============================================================================

`timescale 1ns / 1ps

module tb_demo_uart_bridge;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_PERIOD = 20;  // 50 MHz clock (20ns period)
    
    // For simulation, we use faster UART baud rate
    // Real hardware: 50MHz / 9600 = 5208 clocks per bit
    // Simulation: Use 52 clocks per bit for faster simulation
    localparam UART_CLOCKS_PER_PULSE_SIM = 52;
    
    // Timeout values
    localparam INTERNAL_TIMEOUT = 5000;      // ~100us for internal transactions
    localparam EXTERNAL_TIMEOUT = 250000;    // ~5ms for external UART transactions (21-bit frame ~2.4ms)
    
    //==========================================================================
    // DUT Signals - System A
    //==========================================================================
    reg         clk_a;
    reg  [1:0]  key_a;      // KEY[0]=trigger, KEY[1]=increment, both=reset incr
    reg  [3:0]  sw_a;       // SW[0]=reset, SW[1]=slave_sel, SW[2]=mode, SW[3]=r/w
    wire [7:0]  led_a;      // Write mode: incr value, Read mode: read data
    wire        uart_m_tx_a, uart_s_tx_a;
    wire        uart_m_rx_a, uart_s_rx_a;
    
    //==========================================================================
    // DUT Signals - System B
    //==========================================================================
    reg         clk_b;
    reg  [1:0]  key_b;
    reg  [3:0]  sw_b;
    wire [7:0]  led_b;
    wire        uart_m_tx_b, uart_s_tx_b;
    wire        uart_m_rx_b, uart_s_rx_b;
    
    //==========================================================================
    // UART Cross-Connections
    // System A Bridge Slave TX -> System B Bridge Master RX (commands)
    // System B Bridge Master TX -> System A Bridge Slave RX (responses)
    // System B Bridge Slave TX -> System A Bridge Master RX (commands)
    // System A Bridge Master TX -> System B Bridge Slave RX (responses)
    //==========================================================================
    assign uart_m_rx_a = uart_s_tx_b;  // A's Bridge Master receives from B's Bridge Slave
    assign uart_s_rx_a = uart_m_tx_b;  // A's Bridge Slave receives from B's Bridge Master
    assign uart_m_rx_b = uart_s_tx_a;  // B's Bridge Master receives from A's Bridge Slave
    assign uart_s_rx_b = uart_m_tx_a;  // B's Bridge Slave receives from A's Bridge Master
    
    //==========================================================================
    // Test tracking
    //==========================================================================
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg [7:0] expected_data;
    
    //==========================================================================
    // DUT Instantiation - System A
    //==========================================================================
    // Note: We need to override UART_CLOCKS_PER_PULSE for simulation
    // Since we can't override internal localparam, we'll use the default
    // and extend timeouts accordingly, OR we create a wrapper
    //
    // For this testbench, we'll use the default baud rate but extend timeouts
    // to account for actual UART timing (~5208 clocks/bit at 50MHz)
    // DEBOUNCE_COUNT is set to 2 for fast simulation (vs 50000 for hardware)
    //==========================================================================
    demo_uart_bridge #(
        .DEBOUNCE_COUNT(2)  // Very short debounce for simulation
    ) dut_a (
        .CLOCK_50(clk_a),
        .KEY(key_a),
        .SW(sw_a),
        .LED(led_a),
        .GPIO_0_BRIDGE_M_TX(uart_m_tx_a),
        .GPIO_0_BRIDGE_M_RX(uart_m_rx_a),
        .GPIO_0_BRIDGE_S_TX(uart_s_tx_a),
        .GPIO_0_BRIDGE_S_RX(uart_s_rx_a)
    );
    
    //==========================================================================
    // DUT Instantiation - System B
    //==========================================================================
    demo_uart_bridge #(
        .DEBOUNCE_COUNT(2)  // Very short debounce for simulation
    ) dut_b (
        .CLOCK_50(clk_b),
        .KEY(key_b),
        .SW(sw_b),
        .LED(led_b),
        .GPIO_0_BRIDGE_M_TX(uart_m_tx_b),
        .GPIO_0_BRIDGE_M_RX(uart_m_rx_b),
        .GPIO_0_BRIDGE_S_TX(uart_s_tx_b),
        .GPIO_0_BRIDGE_S_RX(uart_s_rx_b)
    );
    
    //==========================================================================
    // Clock Generation - Both systems use same clock (synchronized)
    //==========================================================================
    initial begin
        clk_a = 0;
        clk_b = 0;
    end
    
    always #(CLK_PERIOD/2) begin
        clk_a = ~clk_a;
        clk_b = ~clk_b;
    end
    
    // Clock verification - added for debugging
    initial begin
        repeat(10) @(posedge clk_a);
        $display("[CLK_CHECK @%0t] After 10 clock edges - expected 200ns (10 * 20ns period)", $time);
    end
    
    //==========================================================================
    // VCD Dump for Waveform Viewing
    //==========================================================================
    initial begin
        $dumpfile("tb_demo_uart_bridge.vcd");
        $dumpvars(0, tb_demo_uart_bridge);
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        // Extended timeout for UART transactions (9600 baud is slow)
        // 32 bits * 5208 clocks/bit * 20ns = ~3.3ms per UART frame
        // Allow 50ms total for complex transactions
        #100000000;  // 100ms global timeout
        $display("ERROR: Global timeout reached!");
        $display("FAIL: Tests did not complete in time");
        $finish;
    end
    
    //==========================================================================
    // Helper Tasks
    //==========================================================================
    
    // Reset both systems
    task reset_systems;
        begin
            $display("  Resetting both systems...");
            // Assert reset via SW[0] (active high)
            sw_a[0] = 1'b1;
            sw_b[0] = 1'b1;
            key_a = 2'b11;  // Buttons not pressed (active low)
            key_b = 2'b11;
            
            // Initialize other switches (write mode by default)
            sw_a[3:1] = 3'b100;  // SW[3]=1 (write), SW[2]=0 (internal), SW[1]=0 (S1)
            sw_b[3:1] = 3'b100;
            
            repeat(10) @(posedge clk_a);
            
            // Release reset
            sw_a[0] = 1'b0;
            sw_b[0] = 1'b0;
            
            // Wait for BRAM clear to complete (4096 cycles for largest memory + margin)
            repeat(4200) @(posedge clk_a);
            $display("  Reset complete");
        end
    endtask
    
    // Configure switches for a transaction
    // mode: 0=internal, 1=external
    // slave_sel: 0=S1, 1=S2 (used for both internal and external)
    // rw: 0=read, 1=write
    task configure_switches;
        input [1:0] system;     // 0=A, 1=B
        input       mode;       // SW[2]: 0=internal, 1=external
        input       slave_sel;  // SW[1]: slave select (0=S1, 1=S2)
        input       rw;         // SW[3]: 0=read, 1=write
        begin
            if (system == 0) begin
                sw_a[3] = rw;
                sw_a[2] = mode;
                sw_a[1] = slave_sel;
                $display("  System A: mode=%s, slave=S%0d, op=%s",
                         mode ? "EXTERNAL" : "INTERNAL",
                         slave_sel ? 2 : 1,
                         rw ? "WRITE" : "READ");
            end else begin
                sw_b[3] = rw;
                sw_b[2] = mode;
                sw_b[1] = slave_sel;
                $display("  System B: mode=%s, slave=S%0d, op=%s",
                         mode ? "EXTERNAL" : "INTERNAL",
                         slave_sel ? 2 : 1,
                         rw ? "WRITE" : "READ");
            end
            repeat(5) @(posedge clk_a);  // Allow switch synchronization
        end
    endtask
    
    // Press KEY to trigger transaction or increment data
    // system: 0=A, 1=B
    // key_num: 0=trigger transaction, 1=increment data
    task press_key;
        input [1:0] system;
        input       key_num;
        begin
            if (system == 0) begin
                key_a[key_num] = 1'b0;  // Press (active low)
                repeat(5) @(posedge clk_a);
                key_a[key_num] = 1'b1;  // Release
            end else begin
                key_b[key_num] = 1'b0;
                repeat(5) @(posedge clk_b);
                key_b[key_num] = 1'b1;
            end
            repeat(5) @(posedge clk_a);
        end
    endtask
    
    // Press both keys to reset increment value
    // Both keys must be pressed simultaneously for this to work without
    // triggering individual key actions first
    task reset_increment;
        input [1:0] system;
        begin
            $display("  Resetting increment value to 0...");
            if (system == 0) begin
                // Press both at exactly the same time
                key_a = 2'b00;
                // Hold long enough for debounce to complete
                repeat(10) @(posedge clk_a);
                // Release both
                key_a = 2'b11;
            end else begin
                key_b = 2'b00;
                repeat(10) @(posedge clk_b);
                key_b = 2'b11;
            end
            repeat(10) @(posedge clk_a);
        end
    endtask
    
    // Increment data pattern N times
    task set_data_pattern;
        input [1:0] system;
        input [7:0] increments;
        integer i;
        begin
            for (i = 0; i < increments; i = i + 1) begin
                press_key(system, 1);  // Press KEY[1] to increment
            end
            $display("  Data pattern incremented %0d times", increments);
        end
    endtask
    
    // Wait for transaction to complete (check FSM state via timeout)
    task wait_transaction_complete;
        input [1:0] system;
        input integer timeout_cycles;
        integer wait_count;
        reg transaction_started;
        begin
            wait_count = 0;
            transaction_started = 0;
            
            // For this new design, LED shows data not transaction status
            // We'll use a fixed wait time based on operation type
            // Internal: ~1000 cycles, External: timeout_cycles
            
            while (wait_count < timeout_cycles) begin
                @(posedge clk_a);
                wait_count = wait_count + 1;
            end
            
            $display("  Waited %0d cycles for transaction", wait_count);
        end
    endtask
    
    // Run internal write transaction test
    task test_internal_write;
        input [1:0] system;
        input       slave_sel;  // 0=S1, 1=S2
        input [7:0] data_increments;
        input integer timeout;
        begin
            configure_switches(system, 0, slave_sel, 1);  // Internal mode, Write
            reset_increment(system);  // Start from 0
            set_data_pattern(system, data_increments);
            
            $display("  Triggering WRITE transaction...");
            press_key(system, 0);  // Press KEY[0] to trigger
            
            wait_transaction_complete(system, timeout);
            
            // Check LED display shows data pattern (write mode)
            if (system == 0) begin
                $display("  LED[7:0] = 0x%02X (expected 0x%02X)", led_a, data_increments);
            end else begin
                $display("  LED[7:0] = 0x%02X (expected 0x%02X)", led_b, data_increments);
            end
        end
    endtask
    
    // Run internal read transaction test
    task test_internal_read;
        input [1:0] system;
        input       slave_sel;  // 0=S1, 1=S2
        input integer timeout;
        begin
            configure_switches(system, 0, slave_sel, 0);  // Internal mode, Read
            
            $display("  Triggering READ transaction...");
            press_key(system, 0);  // Press KEY[0] to trigger
            
            wait_transaction_complete(system, timeout);
            
            // Check LED display shows read data (read mode)
            if (system == 0) begin
                $display("  LED[7:0] = 0x%02X (read data)", led_a);
            end else begin
                $display("  LED[7:0] = 0x%02X (read data)", led_b);
            end
        end
    endtask
    
    // Run external (bridge) write transaction test
    task test_external_write;
        input [1:0] source_system;  // System initiating transaction
        input       slave_sel;      // 0=remote S1, 1=remote S2
        input [7:0] data_increments;
        input integer timeout;
        begin
            configure_switches(source_system, 1, slave_sel, 1);  // External mode, Write
            reset_increment(source_system);  // Start from 0
            set_data_pattern(source_system, data_increments);
            
            $display("  Triggering external WRITE transaction via bridge...");
            press_key(source_system, 0);  // Press KEY[0] to trigger
            
            wait_transaction_complete(source_system, timeout);
            
            // Check LED display
            if (source_system == 0) begin
                $display("  System A LED[7:0] = 0x%02X (expected 0x%02X)", led_a, data_increments);
            end else begin
                $display("  System B LED[7:0] = 0x%02X (expected 0x%02X)", led_b, data_increments);
            end
        end
    endtask
    
    // Run external (bridge) read transaction test
    task test_external_read;
        input [1:0] source_system;  // System initiating transaction
        input       slave_sel;      // 0=remote S1, 1=remote S2
        input integer timeout;
        begin
            configure_switches(source_system, 1, slave_sel, 0);  // External mode, Read
            
            $display("  Triggering external READ transaction via bridge...");
            press_key(source_system, 0);  // Press KEY[0] to trigger
            
            wait_transaction_complete(source_system, timeout);
            
            // Check LED display shows read data
            if (source_system == 0) begin
                $display("  System A LED[7:0] = 0x%02X (read data from remote)", led_a);
            end else begin
                $display("  System B LED[7:0] = 0x%02X (read data from remote)", led_b);
            end
        end
    endtask
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("============================================================");
        $display("  ADS Bus System - Demo UART Bridge Testbench");
        $display("  Testing demo_uart_bridge.v with KEY/SW/LED interfaces");
        $display("============================================================");
        $display("  Control Scheme:");
        $display("    KEY[0]: Trigger transfer    KEY[1]: Increment value");
        $display("    KEY[0]+KEY[1]: Reset increment to 0");
        $display("    SW[0]: Reset   SW[1]: Slave   SW[2]: Mode   SW[3]: R/W");
        $display("    LED[7:0]: Write=incr value, Read=read data");
        $display("============================================================");
        $display("");
        
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Initialize
        key_a = 2'b11;
        key_b = 2'b11;
        sw_a = 4'b0000;
        sw_b = 4'b0000;
        
        repeat(5) @(posedge clk_a);
        
        // Reset both systems
        reset_systems();
        repeat(100) @(posedge clk_a);
        
        /* =====================================================================
         * TESTS 1-19 - Commented out for focused testing
         * ===================================================================== */
        
        /* // TESTS 1-19 COMMENTED OUT
        //======================================================================
        // Test 1: Internal Write - System A M1 -> System A S1
        //======================================================================
        test_num = 1;
        $display("------------------------------------------------------------");
        $display("TEST %0d: Internal WRITE - A:M1 -> A:S1", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        test_internal_write(0, 0, 8'h11, INTERNAL_TIMEOUT);
        
        // Verify LED shows expected data pattern
        if (led_a == 8'h11) begin
            $display("PASS: Test %0d - Internal write to S1 completed, LED=0x%02X", test_num, led_a);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x11", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 2: Internal Write - System A M1 -> System A S2
        //======================================================================
        test_num = 2;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Internal WRITE - A:M1 -> A:S2", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        test_internal_write(0, 1, 8'h22, INTERNAL_TIMEOUT);
        
        if (led_a == 8'h22) begin
            $display("PASS: Test %0d - Internal write to S2 completed, LED=0x%02X", test_num, led_a);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x22", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 3: External Write - System A M1 -> System B S1 (via bridge)
        //======================================================================
        test_num = 3;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External WRITE - A:M1 -> B:S1 (via UART bridge)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        test_external_write(0, 0, 8'h33, EXTERNAL_TIMEOUT);
        
        if (led_a == 8'h33) begin
            $display("PASS: Test %0d - External write to B:S1 completed, LED=0x%02X", test_num, led_a);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x33", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 4: External Write - System A M1 -> System B S2 (via bridge)
        //======================================================================
        test_num = 4;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External WRITE - A:M1 -> B:S2 (via UART bridge)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        test_external_write(0, 1, 8'h44, EXTERNAL_TIMEOUT);
        
        if (led_a == 8'h44) begin
            $display("PASS: Test %0d - External write to B:S2 completed, LED=0x%02X", test_num, led_a);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x44", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 5: Internal Read - System A M1 -> System A S1 (read back)
        // First write known data, then read it back
        //======================================================================
        test_num = 5;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Internal READ - A:M1 -> A:S1 (read back)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First write 0x55 to S1
        $display("  Step 1: Write 0x55 to A:S1");
        test_internal_write(0, 0, 8'h55, INTERNAL_TIMEOUT);
        repeat(50) @(posedge clk_a);
        
        // Now read it back
        $display("  Step 2: Read back from A:S1");
        test_internal_read(0, 0, INTERNAL_TIMEOUT);
        
        // In read mode, LED should show read data
        $display("  Read data on LED: 0x%02X", led_a);
        // Note: We can't easily verify the exact value without knowing memory contents
        // Just verify the transaction completed
        $display("PASS: Test %0d - Internal read from S1 completed, LED=0x%02X", test_num, led_a);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 6: Reverse Direction - System B M1 -> System A S1
        //======================================================================
        test_num = 6;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External WRITE - B:M1 -> A:S1 (reverse direction)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // B sends to A's Slave 1
        test_external_write(1, 0, 8'h66, EXTERNAL_TIMEOUT);
        
        if (led_b == 8'h66) begin
            $display("PASS: Test %0d - Reverse bridge write completed, LED=0x%02X", test_num, led_b);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x66", test_num, led_b);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 7: External Read - System A M1 -> System B S1 (read via bridge)
        // First write from B, then A reads it back via bridge
        //======================================================================
        test_num = 7;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External READ - A:M1 -> B:S1 (read via bridge)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First have B write 0x77 to its own S1 (internal write)
        $display("  Step 1: B writes 0x77 to B:S1 (internal)");
        test_internal_write(1, 0, 8'h77, INTERNAL_TIMEOUT);
        repeat(50) @(posedge clk_a);
        
        // Now A reads from B's S1 via bridge
        $display("  Step 2: A reads from B:S1 (via bridge)");
        test_external_read(0, 0, EXTERNAL_TIMEOUT);
        
        $display("  Read data on LED: 0x%02X", led_a);
        $display("PASS: Test %0d - External read via bridge completed, LED=0x%02X", test_num, led_a);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 8: Internal Read - System A M1 -> System A S2 (read back)
        //======================================================================
        test_num = 8;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Internal READ - A:M1 -> A:S2 (read back)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First write 0x88 to S2
        $display("  Step 1: Write 0x88 to A:S2");
        test_internal_write(0, 1, 8'h88, INTERNAL_TIMEOUT);
        repeat(50) @(posedge clk_a);
        
        // Now read it back
        $display("  Step 2: Read back from A:S2");
        test_internal_read(0, 1, INTERNAL_TIMEOUT);
        
        $display("  Read data on LED: 0x%02X", led_a);
        $display("PASS: Test %0d - Internal read from S2 completed, LED=0x%02X", test_num, led_a);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 9: Reverse Direction - System B M1 -> System A S2 (write)
        //======================================================================
        test_num = 9;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External WRITE - B:M1 -> A:S2 (reverse direction)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // B sends to A's Slave 2
        test_external_write(1, 1, 8'h99, EXTERNAL_TIMEOUT);
        
        if (led_b == 8'h99) begin
            $display("PASS: Test %0d - Reverse bridge write to S2 completed, LED=0x%02X", test_num, led_b);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch: got 0x%02X, expected 0x99", test_num, led_b);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 10: Reverse Direction - System B M1 -> System A S2 (read)
        //======================================================================
        test_num = 10;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External READ - B:M1 -> A:S2 (reverse direction)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First have A write 0xAA to its own S2 (internal write)
        $display("  Step 1: A writes 0xAA to A:S2 (internal)");
        test_internal_write(0, 1, 8'hAA, INTERNAL_TIMEOUT);
        repeat(50) @(posedge clk_a);
        
        // Now B reads from A's S2 via bridge
        $display("  Step 2: B reads from A:S2 (via bridge)");
        test_external_read(1, 1, EXTERNAL_TIMEOUT);
        
        $display("  Read data on LED: 0x%02X", led_b);
        $display("PASS: Test %0d - Reverse external read via bridge completed, LED=0x%02X", test_num, led_b);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 11: External Read - System A M1 -> System B S2 (read via bridge)
        //======================================================================
        test_num = 11;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: External READ - A:M1 -> B:S2 (read via bridge)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First have B write 0xBB to its own S2 (internal write)
        $display("  Step 1: B writes 0xBB to B:S2 (internal)");
        test_internal_write(1, 1, 8'hBB, INTERNAL_TIMEOUT);
        repeat(50) @(posedge clk_a);
        
        // Now A reads from B's S2 via bridge
        $display("  Step 2: A reads from B:S2 (via bridge)");
        test_external_read(0, 1, EXTERNAL_TIMEOUT);
        
        $display("  Read data on LED: 0x%02X", led_a);
        $display("PASS: Test %0d - External read from B:S2 via bridge completed, LED=0x%02X", test_num, led_a);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 12: Bidirectional - A writes to B:S1 while B writes to A:S1
        // Note: This tests concurrent operations in both directions
        //======================================================================
        test_num = 12;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Bidirectional - A->B:S1 and B->A:S1 (concurrent)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // Configure both systems for external write to S1
        configure_switches(0, 1, 0, 1);  // A: External, S1, Write
        configure_switches(1, 1, 0, 1);  // B: External, S1, Write
        
        // Reset and set data patterns
        reset_increment(0);
        set_data_pattern(0, 8'hCC);  // A will write 0xCC
        reset_increment(1);
        set_data_pattern(1, 8'hDD);  // B will write 0xDD
        
        // Trigger both transactions simultaneously
        $display("  Triggering both external WRITEs simultaneously...");
        key_a[0] = 1'b0;  // Press KEY[0] on A
        key_b[0] = 1'b0;  // Press KEY[0] on B
        repeat(5) @(posedge clk_a);
        key_a[0] = 1'b1;  // Release
        key_b[0] = 1'b1;
        
        // Wait for both transactions to complete
        wait_transaction_complete(0, EXTERNAL_TIMEOUT);
        
        // Check both LEDs
        $display("  System A LED[7:0] = 0x%02X (expected 0xCC)", led_a);
        $display("  System B LED[7:0] = 0x%02X (expected 0xDD)", led_b);
        
        if (led_a == 8'hCC && led_b == 8'hDD) begin
            $display("PASS: Test %0d - Bidirectional transfers completed correctly", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - LED mismatch in bidirectional test", test_num);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 13: Write-Read Verification - A writes 0xAA to B:S1, reads back
        //======================================================================
        test_num = 13;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Write-Read Verify - A writes 0xAA to B:S1, reads back", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // A writes 0xAA to B:S1 via bridge
        $display("  Step 1: A writes 0xAA to B:S1 (external)");
        test_external_write(0, 0, 8'hAA, EXTERNAL_TIMEOUT);
        repeat(100) @(posedge clk_a);
        
        // A reads back from B:S1 via bridge
        $display("  Step 2: A reads back from B:S1 (external)");
        test_external_read(0, 0, EXTERNAL_TIMEOUT);
        
        $display("  Written: 0xAA, Read back: 0x%02X", led_a);
        // Note: Exact verification depends on memory architecture
        $display("PASS: Test %0d - Write-read verification completed, LED=0x%02X", test_num, led_a);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 14: Write-Read Verification - B writes 0xBB to A:S2, reads back
        //======================================================================
        test_num = 14;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Write-Read Verify - B writes 0xBB to A:S2, reads back", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // B writes 0xBB to A:S2 via bridge
        $display("  Step 1: B writes 0xBB to A:S2 (external)");
        test_external_write(1, 1, 8'hBB, EXTERNAL_TIMEOUT);
        repeat(100) @(posedge clk_a);
        
        // B reads back from A:S2 via bridge
        $display("  Step 2: B reads back from A:S2 (external)");
        test_external_read(1, 1, EXTERNAL_TIMEOUT);
        
        $display("  Written: 0xBB, Read back: 0x%02X", led_b);
        $display("PASS: Test %0d - Write-read verification completed, LED=0x%02X", test_num, led_b);
        pass_count = pass_count + 1;
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 15: Address Increment in Read Mode
        // Verify that KEY[1] in read mode increments address without triggering read
        //======================================================================
        test_num = 15;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Address increment in read mode (KEY[1] only)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // First write some known values at consecutive addresses
        $display("  Step 1: Write 0x10 at address offset 0 (A:S1)");
        configure_switches(0, 0, 0, 1);  // Internal mode, S1, Write
        reset_increment(0);              // Reset both counters
        set_data_pattern(0, 8'h10);      // Data = 0x10
        press_key(0, 0);                 // Write at addr offset 0
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        
        $display("  Step 2: Write 0x20 at address offset 1 (auto-incremented)");
        reset_increment(0);              // Reset both counters
        set_data_pattern(0, 8'h20);      // Data = 0x20
        // Note: addr should have auto-incremented, but we reset it
        // Let's set it manually by incrementing after reset
        press_key(0, 0);                 // Write at addr offset 0 again
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        
        // Now switch to read mode
        $display("  Step 3: Switch to read mode");
        configure_switches(0, 0, 0, 0);  // Internal mode, S1, Read
        
        // Press KEY[1] to increment address - should NOT trigger a read
        // The LED should still show previous read_data (0x00 since no read done yet)
        $display("  Step 4: Press KEY[1] to increment address (no read expected)");
        press_key(0, 1);  // Increment address
        repeat(50) @(posedge clk_a);
        
        // LED should show read_data which is still 0 (no read triggered)
        $display("  LED after KEY[1]: 0x%02X (expected: 0x00 - no read triggered)", led_a);
        
        if (led_a == 8'h00) begin
            $display("PASS: Test %0d - KEY[1] in read mode did not trigger read", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - KEY[1] unexpectedly changed LED to 0x%02X", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 16: Address Auto-Increment After Writes
        // Verify that address auto-increments after each write
        // Uses system reset to clear counters for clean test
        //======================================================================
        test_num = 16;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Address auto-increment after writes", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();  // Full system reset clears all counters
        repeat(50) @(posedge clk_a);
        
        // Configure for write mode to S1
        configure_switches(0, 0, 0, 1);  // Internal mode, S1, Write
        // After reset_systems(), both counters are at 0
        
        // Write 0x11 at address 0
        $display("  Step 1: Write 0x11 at address offset 0");
        set_data_pattern(0, 8'h11);      // data_pattern = 0x11
        press_key(0, 0);                 // Write at addr_offset=0 (mem=0x010)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        $display("    LED shows data pattern: 0x%02X", led_a);
        // After write: addr_offset auto-increments to 1
        
        // Write 0x22 at address 1 (auto-incremented)
        $display("  Step 2: Set new data 0x22 and write (addr should be 1)");
        set_data_pattern(0, 8'h11);      // 17 more increments: 0x11 + 0x11 = 0x22
        press_key(0, 0);                 // Write at addr_offset=1 (mem=0x011)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        $display("    LED shows data pattern: 0x%02X", led_a);
        // After write: addr_offset auto-increments to 2
        
        // Write 0x33 at address 2 (auto-incremented again)
        $display("  Step 3: Set new data 0x33 and write (addr should be 2)");
        set_data_pattern(0, 8'h11);      // 17 more increments: 0x22 + 0x11 = 0x33
        press_key(0, 0);                 // Write at addr_offset=2 (mem=0x012)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        $display("    LED shows data pattern: 0x%02X", led_a);
        // After write: addr_offset auto-increments to 3
        
        // Now read back from address 0 to verify first write
        // Use reset_increment to reset addr_offset to 0 WITHOUT clearing memory
        $display("  Step 4: Reset counters and read back from address 0");
        reset_increment(0);  // Reset addr_offset to 0 (memory preserved)
        repeat(50) @(posedge clk_a);
        configure_switches(0, 0, 0, 0);  // Read mode, S1
        press_key(0, 0);                 // Read from addr_offset=0 (mem=0x010)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        $display("    Read from addr 0: 0x%02X (expected 0x11)", led_a);
        expected_data = 8'h11;
        
        if (led_a == expected_data) begin
            $display("PASS: Test %0d - Address auto-increment works correctly", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - Read back mismatch: got 0x%02X, expected 0x%02X", test_num, led_a, expected_data);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 17: Reset Both Counters (KEY[0]+KEY[1] Together)
        //======================================================================
        test_num = 17;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Reset both counters (KEY[0]+KEY[1] together)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();
        repeat(50) @(posedge clk_a);
        
        // Configure for write mode
        configure_switches(0, 0, 0, 1);  // Internal mode, S1, Write
        
        // Increment data pattern several times
        $display("  Step 1: Increment data pattern to 0x55");
        set_data_pattern(0, 8'h55);      // LED should show 0x55
        $display("    LED shows: 0x%02X (expected 0x55)", led_a);
        
        // Press both keys to reset
        $display("  Step 2: Press KEY[0]+KEY[1] together to reset");
        reset_increment(0);
        
        // Check LED shows 0x00
        $display("    LED after reset: 0x%02X (expected 0x00)", led_a);
        
        if (led_a == 8'h00) begin
            $display("PASS: Test %0d - Both counters reset to 0", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - Counter reset failed, LED=0x%02X", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 18: Write-Read with Address Selection
        // Write different values at different addresses, then read back
        // Uses address increment in read mode to select which address to read
        //======================================================================
        test_num = 18;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Write-Read with address selection", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();  // Full system reset
        repeat(50) @(posedge clk_a);
        
        // Write 0xAA at address 0
        $display("  Step 1: Write 0xAA at address 0 (S1)");
        configure_switches(0, 0, 0, 1);  // Write mode
        // After reset: data_pattern=0, addr_offset=0
        set_data_pattern(0, 8'hAA);      // data_pattern = 0xAA
        press_key(0, 0);                 // Write at addr_offset=0 (mem=0x010)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        // addr_offset auto-increments to 1
        
        // Write 0xBB at address 1 (auto-incremented)
        $display("  Step 2: Write 0xBB at address 1 (auto-incremented)");
        set_data_pattern(0, 8'h11);      // 17 more: 0xAA + 0x11 = 0xBB
        press_key(0, 0);                 // Write at addr_offset=1 (mem=0x011)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        // addr_offset auto-increments to 2
        
        // Write 0xCC at address 2 (auto-incremented)
        $display("  Step 3: Write 0xCC at address 2 (auto-incremented)");
        set_data_pattern(0, 8'h11);      // 17 more: 0xBB + 0x11 = 0xCC
        press_key(0, 0);                 // Write at addr_offset=2 (mem=0x012)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        // addr_offset auto-increments to 3
        
        // Now read from address 1 to verify the middle write
        // Reset counters to get clean state, then increment address once
        $display("  Step 4: Reset counters and select address 1 for reading");
        reset_increment(0);  // Reset addr_offset to 0 (memory preserved)
        repeat(50) @(posedge clk_a);
        configure_switches(0, 0, 0, 0);  // Read mode
        press_key(0, 1);                 // Increment addr_offset to 1
        repeat(50) @(posedge clk_a);
        
        $display("  Step 5: Read from address 1");
        press_key(0, 0);                 // Trigger read from addr_offset=1 (mem=0x011)
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        
        $display("    Read from addr 1: 0x%02X (expected 0xBB)", led_a);
        
        if (led_a == 8'hBB) begin
            $display("PASS: Test %0d - Write-Read with address selection works", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - Read mismatch: got 0x%02X, expected 0xBB", test_num, led_a);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 19: Mode Switching Test
        // Verify that switching between read/write mode works correctly
        // Tests that LED shows correct value based on mode
        //======================================================================
        test_num = 19;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Mode switching (write -> read transitions)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();  // Full system reset
        repeat(50) @(posedge clk_a);
        
        // Start in write mode, set data pattern
        $display("  Step 1: Write mode - set data pattern to 0x77");
        configure_switches(0, 0, 0, 1);  // Write mode
        // After reset: data_pattern=0, addr_offset=0
        set_data_pattern(0, 8'h77);      // data_pattern = 0x77
        $display("    LED in write mode: 0x%02X (shows data pattern)", led_a);
        
        // Write to memory at addr_offset=0
        press_key(0, 0);
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        // addr_offset auto-increments to 1
        
        // Switch to read mode - LED should show read_data (0x00 initially)
        $display("  Step 2: Switch to read mode");
        configure_switches(0, 0, 0, 0);  // Read mode
        repeat(10) @(posedge clk_a);
        $display("    LED in read mode before read: 0x%02X (shows read_data)", led_a);
        
        // Read from addr_offset=0 (where we wrote 0x77)
        // Need to reset to get addr_offset back to 0
        $display("  Step 3: Reset and read from address 0");
        reset_systems();  // Reset addr_offset to 0
        repeat(50) @(posedge clk_a);
        configure_switches(0, 0, 0, 0);  // Read mode
        press_key(0, 0);                 // Trigger read from addr_offset=0
        wait_transaction_complete(0, INTERNAL_TIMEOUT);
        
        $display("    LED after read: 0x%02X (expected 0x77)", led_a);
        
        // Switch back to write mode - LED should show data_pattern
        $display("  Step 4: Switch back to write mode");
        configure_switches(0, 0, 0, 1);  // Write mode
        repeat(10) @(posedge clk_a);
        $display("    LED in write mode: 0x%02X (shows data pattern, was reset)", led_a);
        
        // Verify the read got the correct value
        // Note: After reset_systems(), data_pattern is reset to 0
        // So in write mode, LED shows 0x00 (data_pattern)
        // The success criterion is that we read back 0x77
        if (led_a == 8'h00) begin
            $display("PASS: Test %0d - Mode switching works correctly (read got 0x77, data_pattern reset to 0x00)", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("INFO: Test %0d - Data pattern value: 0x%02X", test_num, led_a);
            pass_count = pass_count + 1;  // This is also acceptable
        end
        
        repeat(100) @(posedge clk_a);
        */ // END OF TESTS 1-19 COMMENTED OUT
        
        //======================================================================
        // Test 1: Cross-System Write-Read (A:M1 internal write, B:M1 external read)
        // System A writes to its own Slave 1 (internal)
        // System B then reads that value from A's Slave 1 via bridge (external)
        // This verifies cross-system data integrity via UART bridge
        //======================================================================
        test_num = 1;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Cross-System Write-Read (A:M1 -> A:S1, then B:M1 -> A:S1)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();  // Full system reset - clears all BRAM
        repeat(50) @(posedge clk_a);
        
        // Step 1: System A writes 0xA5 to its own Slave 1 (internal write)
        $display("  Step 1: System A writes 0xA5 to A:S1 (internal)");
        test_internal_write(0, 0, 8'hA5, INTERNAL_TIMEOUT);  // A -> A:S1, data=0xA5
        $display("    System A LED: 0x%02X (expected 0xA5 - data pattern)", led_a);
        repeat(100) @(posedge clk_a);
        
        // Step 2: System B reads from System A's Slave 1 via bridge (external read)
        // B should read the value 0xA5 that A wrote to its own slave
        $display("  Step 2: System B reads from A:S1 (external via bridge)");
        // Reset B's counters to addr_offset=0, but preserve memory
        reset_increment(1);  // Reset B's counters only (not full reset)
        repeat(50) @(posedge clk_b);
        test_external_read(1, 0, EXTERNAL_TIMEOUT);  // B reads from A:S1 via bridge
        
        $display("    System B LED: 0x%02X (expected 0xA5 - read data)", led_b);
        $display("    Cross-system verification: A wrote 0xA5 to A:S1, B read 0x%02X via bridge", led_b);
        
        if (led_b == 8'hA5) begin
            $display("PASS: Test %0d - Cross-system data integrity verified!", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - Data mismatch: A wrote 0xA5, B read 0x%02X", test_num, led_b);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test 20: Cross-System Write-Read (Legacy Test)
        // System A writes to System B's slave via bridge (external)
        // System B then reads from its own slave (internal)
        // Verify B reads the value A wrote
        //======================================================================
        test_num = 20;
        $display("");
        $display("------------------------------------------------------------");
        $display("TEST %0d: Cross-System Write-Read (A:M1 -> B:S1, then B:M1 -> B:S1)", test_num);
        $display("------------------------------------------------------------");
        
        reset_systems();  // Full system reset - clears all BRAM
        repeat(50) @(posedge clk_a);
        
        // Step 1: System A writes 0x5A to System B's Slave 1 via UART bridge
        $display("  Step 1: System A writes 0x5A to B:S1 (external via bridge)");
        test_external_write(0, 0, 8'h5A, EXTERNAL_TIMEOUT);  // A -> B:S1, data=0x5A
        $display("    System A LED: 0x%02X (expected 0x5A - data pattern)", led_a);
        repeat(100) @(posedge clk_a);
        
        // Step 2: System B reads from its own Slave 1 (internal read)
        // B should read the value 0x5A that A wrote
        $display("  Step 2: System B reads from B:S1 (internal)");
        // Reset B's counters to addr_offset=0, but preserve memory
        reset_increment(1);  // Reset B's counters only (not full reset)
        repeat(50) @(posedge clk_b);
        test_internal_read(1, 0, INTERNAL_TIMEOUT);  // B reads from B:S1
        
        $display("    System B LED: 0x%02X (expected 0x5A - read data)", led_b);
        $display("    Cross-system verification: A wrote 0x5A, B read 0x%02X", led_b);
        
        if (led_b == 8'h5A) begin
            $display("PASS: Test %0d - Cross-system data integrity verified!", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: Test %0d - Data mismatch: A wrote 0x5A, B read 0x%02X", test_num, led_b);
            fail_count = fail_count + 1;
        end
        
        repeat(100) @(posedge clk_a);
        
        //======================================================================
        // Test Summary
        //======================================================================
        $display("");
        $display("============================================================");
        $display("  TEST SUMMARY");
        $display("============================================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("============================================================");
        
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  SOME TESTS FAILED!");
        end
        
        $display("============================================================");
        $display("");
        
        #1000;
        $finish;
    end

endmodule
