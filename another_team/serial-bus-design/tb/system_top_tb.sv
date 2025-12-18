`timescale 1ns/1ps

module system_top_tb;
    // Clock and reset stimulus
    logic clk;
    logic btn_reset;
    logic btn_trigger;
    logic [7:0] leds;

    // Device under test
    system_top dut (
        .clk(clk),
        .btn_reset(btn_reset),
        .btn_trigger(btn_trigger),
        .leds(leds)
    );

    // Generate 50 MHz equivalent clock (20 ns period)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Simple task to assert trigger for one cycle
    task automatic pulse_trigger;
        begin
            btn_trigger <= 1'b1;
            @(posedge clk);
            btn_trigger <= 1'b0;
        end
    endtask

    // Scoreboard state
    byte led_history [0:5];
    int trigger_count;
    bit distinct_value_seen;
    byte prev_led_value;

    initial begin
        // Initial conditions
        btn_reset = 1'b1; // active-low reset inside DUT
        btn_trigger = 1'b0;
        trigger_count = 0;
        foreach (led_history[i]) led_history[i] = '0;

        // Hold reset asserted for a few cycles then release and keep low
        repeat (5) @(posedge clk);
        btn_reset = 1'b0;
        repeat (10) @(posedge clk);

        // Issue six triggers, sampling LEDs after the read data returns
        prev_led_value = leds;
        distinct_value_seen = 1'b0;

        for (int i = 0; i < 6; i++) begin
            pulse_trigger();
            trigger_count++;

            @(posedge dut.init1_data_in_valid);
            @(posedge clk);

            led_history[i] = leds;
            if (led_history[i] != prev_led_value)
                distinct_value_seen = 1'b1;
            prev_led_value = led_history[i];

            $display("[%0t] Trigger %0d -> LED value %02h", $time, i, led_history[i]);
        end

        if (!distinct_value_seen) begin
            $error("LED values did not change across triggers; circular buffer may not be advancing");
        end

        $display("[%0t] System top testbench completed after %0d triggers", $time, trigger_count);
        $finish;
    end
endmodule
