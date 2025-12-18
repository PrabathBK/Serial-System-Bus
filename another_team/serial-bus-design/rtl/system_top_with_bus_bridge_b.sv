`timescale 1ns/1ps

module system_top_with_bus_bridge_b (
    input  logic       clk,
    input  logic       btn_reset,
    input  logic       uart_rx,
    output logic       uart_tx,
    output logic [7:0] leds
);
    // Synchronise reset input to the local clock domain.
    logic reset_sync_ff1;
    logic reset_sync_ff2;
    always_ff @(posedge clk) begin
        reset_sync_ff1 <= ~btn_reset;
        reset_sync_ff2 <= reset_sync_ff1;
    end

    logic rst_n;
    assign rst_n = ~reset_sync_ff2;

    // Address map for Bus B resources.
    localparam logic [15:0] TARGET1_BASE = 16'h0000;
    localparam int unsigned TARGET1_SIZE = 16'd2048;
    localparam logic [15:0] TARGET2_BASE = 16'h4000;
    localparam int unsigned TARGET2_SIZE = 16'd4096;
    localparam logic [15:0] SPLIT_TARGET_BASE = 16'h8000;
    localparam int unsigned SPLIT_TARGET_SIZE = 16'd4096;

    // Initiator (bridge wrapper) interface wires.
    logic         bridge_init_req;
    logic [15:0]  bridge_init_addr_out;
    logic         bridge_init_addr_out_valid;
    logic [7:0]   bridge_init_data_out;
    logic         bridge_init_data_out_valid;
    logic         bridge_init_rw;
    logic         bridge_init_ready;
    logic         bridge_init_grant;
    logic [7:0]   bridge_init_data_in;
    logic         bridge_init_data_in_valid;
    logic         bridge_init_ack;
    logic         bridge_init_split_ack;

    // Target 1 interface wires.
    logic [15:0]  target1_addr_in;
    logic         target1_addr_in_valid;
    logic [7:0]   target1_data_in;
    logic         target1_data_in_valid;
    logic         target1_rw;
    logic [7:0]   target1_data_out;
    logic         target1_data_out_valid;
    logic         target1_ack;
    logic         target1_ready;

    // Target 2 interface wires.
    logic [15:0]  target2_addr_in;
    logic         target2_addr_in_valid;
    logic [7:0]   target2_data_in;
    logic         target2_data_in_valid;
    logic         target2_rw;
    logic [7:0]   target2_data_out;
    logic         target2_data_out_valid;
    logic         target2_ack;
    logic         target2_ready;

    // Split target interface wires.
    logic [15:0]  split_target_addr_in;
    logic         split_target_addr_in_valid;
    logic [7:0]   split_target_data_in;
    logic         split_target_data_in_valid;
    logic         split_target_rw;
    logic [7:0]   split_target_data_out;
    logic         split_target_data_out_valid;
    logic         split_target_ack;
    logic         split_target_ready;
    logic         split_target_split_ack;
    logic         split_target_req;
    logic         split_target_grant;
    logic [7:0]   split_target_last_write;

    // Tied-off signals for the unused second initiator slot.
    logic         init2_grant_unused;
    logic [7:0]   init2_data_in_unused;
    logic         init2_data_in_valid_unused;
    logic         init2_ack_unused;
    logic         init2_split_ack_unused;

    // UART-connected bus bridge initiator wrapper.
    bus_bridge_initiator_uart_wrapper u_bridge_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .init_req(bridge_init_req),
        .init_addr_out(bridge_init_addr_out),
        .init_addr_out_valid(bridge_init_addr_out_valid),
        .init_data_out(bridge_init_data_out),
        .init_data_out_valid(bridge_init_data_out_valid),
        .init_rw(bridge_init_rw),
        .init_ready(bridge_init_ready),
        .init_grant(bridge_init_grant),
        .init_data_in(bridge_init_data_in),
        .init_data_in_valid(bridge_init_data_in_valid),
        .init_ack(bridge_init_ack),
        .init_split_ack(bridge_init_split_ack)
    );

    // Local bus targets.
    target #(
        .INTERNAL_ADDR_BITS(11)
    ) u_target_1 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target1_addr_in),
        .target_addr_in_valid(target1_addr_in_valid),
        .target_data_in(target1_data_in),
        .target_data_in_valid(target1_data_in_valid),
        .target_rw(target1_rw),
        .target_data_out(target1_data_out),
        .target_data_out_valid(target1_data_out_valid),
        .target_ack(target1_ack),
        .target_ready(target1_ready),
        .target_last_write()
    );

    target #(
        .INTERNAL_ADDR_BITS(12)
    ) u_target_2 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target2_addr_in),
        .target_addr_in_valid(target2_addr_in_valid),
        .target_data_in(target2_data_in),
        .target_data_in_valid(target2_data_in_valid),
        .target_rw(target2_rw),
        .target_data_out(target2_data_out),
        .target_data_out_valid(target2_data_out_valid),
        .target_ack(target2_ack),
        .target_ready(target2_ready),
        .target_last_write()
    );

    split_target #(
        .INTERNAL_ADDR_BITS(12),
        .READ_LATENCY(4)
    ) u_split_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_target_grant),
        .target_addr_in(split_target_addr_in),
        .target_addr_in_valid(split_target_addr_in_valid),
        .target_data_in(split_target_data_in),
        .target_data_in_valid(split_target_data_in_valid),
        .target_rw(split_target_rw),
        .split_req(split_target_req),
        .target_data_out(split_target_data_out),
        .target_data_out_valid(split_target_data_out_valid),
        .target_ack(split_target_ack),
        .target_split_ack(split_target_split_ack),
        .target_ready(split_target_ready),
        .split_target_last_write(split_target_last_write)
    );

    // Bus interconnect instantiation.
    bus #(
        .TARGET1_BASE(TARGET1_BASE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_BASE(TARGET2_BASE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .TARGET3_BASE(SPLIT_TARGET_BASE),
        .TARGET3_SIZE(SPLIT_TARGET_SIZE)
    ) bus_b (
        .clk(clk),
        .rst_n(rst_n),
        // Initiator 1 (bridge wrapper)
        .init1_req(bridge_init_req),
        .init1_data_out(bridge_init_data_out),
        .init1_data_out_valid(bridge_init_data_out_valid),
        .init1_addr_out(bridge_init_addr_out),
        .init1_addr_out_valid(bridge_init_addr_out_valid),
        .init1_rw(bridge_init_rw),
        .init1_ready(bridge_init_ready),
        .init1_grant(bridge_init_grant),
        .init1_data_in(bridge_init_data_in),
        .init1_data_in_valid(bridge_init_data_in_valid),
        .init1_ack(bridge_init_ack),
        .init1_split_ack(bridge_init_split_ack),
        // Initiator 2 (unused)
        .init2_req(1'b0),
        .init2_data_out(8'd0),
        .init2_data_out_valid(1'b0),
        .init2_addr_out(16'd0),
        .init2_addr_out_valid(1'b0),
        .init2_rw(1'b1),
        .init2_ready(1'b1),
        .init2_grant(init2_grant_unused),
        .init2_data_in(init2_data_in_unused),
        .init2_data_in_valid(init2_data_in_valid_unused),
        .init2_ack(init2_ack_unused),
        .init2_split_ack(init2_split_ack_unused),
        // Target 1
        .target1_ready(target1_ready),
        .target1_ack(target1_ack),
        .target1_data_out(target1_data_out),
        .target1_data_out_valid(target1_data_out_valid),
        .target1_addr_in(target1_addr_in),
        .target1_addr_in_valid(target1_addr_in_valid),
        .target1_data_in(target1_data_in),
        .target1_data_in_valid(target1_data_in_valid),
        .target1_rw(target1_rw),
        // Target 2
        .target2_ready(target2_ready),
        .target2_ack(target2_ack),
        .target2_data_out(target2_data_out),
        .target2_data_out_valid(target2_data_out_valid),
        .target2_addr_in(target2_addr_in),
        .target2_addr_in_valid(target2_addr_in_valid),
        .target2_data_in(target2_data_in),
        .target2_data_in_valid(target2_data_in_valid),
        .target2_rw(target2_rw),
        // Split target
        .split_target_ready(split_target_ready),
        .split_target_ack(split_target_ack),
        .split_target_split_ack(split_target_split_ack),
        .split_target_data_out(split_target_data_out),
        .split_target_data_out_valid(split_target_data_out_valid),
        .split_target_req(split_target_req),
        .split_target_addr_in(split_target_addr_in),
        .split_target_addr_in_valid(split_target_addr_in_valid),
        .split_target_data_in(split_target_data_in),
        .split_target_data_in_valid(split_target_data_in_valid),
        .split_target_rw(split_target_rw),
        .split_target_grant(split_target_grant)
    );

    // Display most recent write observed by the split-capable target.
    assign leds = split_target_last_write;

endmodule
