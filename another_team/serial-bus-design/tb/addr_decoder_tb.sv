`timescale 1ns/1ps

module addr_decoder_tb;
    logic clk;
    logic rst_n;

    logic bus_data_in;
    logic bus_data_in_valid;
    logic bus_mode;
    logic [2:0] release_valids;

    logic target_1_valid;
    logic target_2_valid;
    logic target_3_valid;
    logic [1:0] sel;

    localparam bit [15:0] ADDR_S1 = 16'h0012; // falls in Slave 1 range
    localparam bit [15:0] ADDR_S2 = 16'h4ABC; // falls in Slave 2 range
    localparam bit [15:0] ADDR_S3 = 16'h8F00; // falls in Slave 3 range

    addr_decoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_data_in(bus_data_in),
        .bus_data_in_valid(bus_data_in_valid),
        .bus_mode(bus_mode),
        .release_valids(release_valids),
        .target_1_valid(target_1_valid),
        .target_2_valid(target_2_valid),
        .target_3_valid(target_3_valid),
        .sel(sel)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            bus_data_in = 1'b0;
            bus_data_in_valid = 1'b0;
            bus_mode = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            release_valids = 3'b000;
            @(posedge clk);
        end
    endtask

    task automatic send_address(input bit [15:0] addr);
        bus_mode = 1'b0;
        bus_data_in_valid = 1'b0;
        release_valids = 3'b000;
        @(posedge clk);
        for (int i = 0; i < 16; i++) begin
            bus_data_in = addr[i];
            bus_data_in_valid = 1'b1;
            release_valids = 3'b000;
            @(posedge clk);
        end
        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;
        release_valids = 3'b000;
        @(posedge clk);
    endtask

    task automatic send_data_byte(input bit [7:0] data, input logic [2:0] release_mask);
        bus_mode = 1'b1;
        for (int i = 0; i < 8; i++) begin
            bus_data_in = data[i];
            bus_data_in_valid = 1'b1;
            release_valids = 3'b000;
            @(posedge clk);
        end
        bus_data_in_valid = 1'b0;
        bus_data_in = 1'b0;
        release_valids = release_mask;
        @(posedge clk);
        release_valids = 3'b000;
        @(posedge clk);
    endtask

    task automatic check_targets(input logic exp_t1, input logic exp_t2, input logic exp_t3, input logic [1:0] exp_sel);
        if ({target_3_valid, target_2_valid, target_1_valid} !== {exp_t3, exp_t2, exp_t1}) begin
            $error("[%0t] target valids mismatch. exp=%b%b%b got=%b%b%b", $time,
                   exp_t3, exp_t2, exp_t1,
                   target_3_valid, target_2_valid, target_1_valid);
        end
        if (sel !== exp_sel)
            $error("[%0t] sel mismatch. Expected %b got %b", $time, exp_sel, sel);
    endtask

    initial begin
        reset_dut();

        send_address(ADDR_S1);
        check_targets(1'b1, 1'b0, 1'b0, 2'b00);
        send_data_byte(8'hAA, 3'b001);
        check_targets(1'b0, 1'b0, 1'b0, 2'b00);

        send_address(ADDR_S2);
        check_targets(1'b0, 1'b1, 1'b0, 2'b01);
        send_data_byte(8'h55, 3'b010);
        check_targets(1'b0, 1'b0, 1'b0, 2'b00);

        send_address(ADDR_S3);
        check_targets(1'b0, 1'b0, 1'b1, 2'b10);
        send_data_byte(8'h5A, 3'b100);
        check_targets(1'b0, 1'b0, 1'b0, 2'b00);

        send_address(ADDR_S1);
        check_targets(1'b1, 1'b0, 1'b0, 2'b00);
        send_data_byte(8'hC3, 3'b001);
        check_targets(1'b0, 1'b0, 1'b0, 2'b00);

        repeat (5) @(posedge clk);
        $display("[%0t] addr_decoder testbench completed.", $time);
        $finish;
    end
endmodule
