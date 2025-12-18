`timescale 1ns/1ps

module system_top_with_bus_bridge_symmetric (
    input  logic       clk,
    input  logic       btn_reset,
    input  logic       btn_trigger,
    input  logic       bridge_target_uart_rx,
    output logic       bridge_target_uart_tx,
    input  logic       bridge_initiator_uart_rx,
    output logic       bridge_initiator_uart_tx,
    output logic [7:0] leds
);
    // Synchronise push-button inputs and derive clean control pulses.
    logic reset_sync_ff1;
    logic reset_sync_ff2;
    always_ff @(posedge clk) begin
        reset_sync_ff1 <= ~btn_reset;
        reset_sync_ff2 <= reset_sync_ff1;
    end

    logic rst_n;
    assign rst_n = ~reset_sync_ff2;

    logic trigger_sync_ff1;
    logic trigger_sync_ff2;
    always_ff @(posedge clk) begin
        trigger_sync_ff1 <= btn_trigger;
        trigger_sync_ff2 <= trigger_sync_ff1;
    end

    logic trigger_sync_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            trigger_sync_prev <= 1'b0;
        else
            trigger_sync_prev <= trigger_sync_ff2;
    end

    logic local_trigger_pulse;
    assign local_trigger_pulse = trigger_sync_ff2 & ~trigger_sync_prev;

    // Address map constants shared between both bus instances.
    localparam logic [15:0] TARGET0_BASE = 16'h0000;
    localparam int unsigned TARGET0_SIZE = 16'd2048;
    localparam logic [15:0] TARGET1_BASE = 16'h4000;
    localparam int unsigned TARGET1_SIZE = 16'd4096;
    localparam logic [15:0] BRIDGE_BASE_ADDR = 16'h8000;
    localparam int unsigned BRIDGE_TARGET0_SIZE = 16'd4096;
    localparam int unsigned BRIDGE_TARGET1_SIZE = 16'd2048;
    localparam int unsigned BRIDGE_TARGET2_SIZE = 16'd10240;
    localparam int unsigned BRIDGE_TOTAL_SPAN = BRIDGE_TARGET0_SIZE + BRIDGE_TARGET1_SIZE + BRIDGE_TARGET2_SIZE;
    localparam logic [15:0] REMOTE_TARGET_ADDR = BRIDGE_BASE_ADDR + BRIDGE_TARGET0_SIZE + 16'h0004;
    localparam logic [7:0]  LOCAL_INIT_WRITE = 8'hA5;

    // Local initiator wiring.
    logic         init_local_req;
    logic [15:0]  init_local_addr_out;
    logic         init_local_addr_out_valid;
    logic [7:0]   init_local_data_out;
    logic         init_local_data_out_valid;
    logic         init_local_rw;
    logic         init_local_ready;
    logic         init_local_grant;
    logic [7:0]   init_local_data_in;
    logic         init_local_data_in_valid;
    logic         init_local_ack;
    logic         init_local_split_ack;

    // Bus bridge initiator wrapper wiring.
    logic         init_bridge_req;
    logic [15:0]  init_bridge_addr_out;
    logic         init_bridge_addr_out_valid;
    logic [7:0]   init_bridge_data_out;
    logic         init_bridge_data_out_valid;
    logic         init_bridge_rw;
    logic         init_bridge_ready;
    logic         init_bridge_grant;
    logic [7:0]   init_bridge_data_in;
    logic         init_bridge_data_in_valid;
    logic         init_bridge_ack;
    logic         init_bridge_split_ack;

    // Target 0 interface wiring.
    logic [15:0]  target0_addr_in;
    logic         target0_addr_in_valid;
    logic [7:0]   target0_data_in;
    logic         target0_data_in_valid;
    logic         target0_rw;
    logic [7:0]   target0_data_out;
    logic         target0_data_out_valid;
    logic         target0_ack;
    logic         target0_ready;

    // Target 1 interface wiring.
    logic [15:0]  target1_addr_in;
    logic         target1_addr_in_valid;
    logic [7:0]   target1_data_in;
    logic         target1_data_in_valid;
    logic         target1_rw;
    logic [7:0]   target1_data_out;
    logic         target1_data_out_valid;
    logic         target1_ack;
    logic         target1_ready;

    // Bus bridge target wrapper wiring (occupies the split target slot).
    logic [15:0]  bridge_target_addr_in;
    logic         bridge_target_addr_in_valid;
    logic [7:0]   bridge_target_data_in;
    logic         bridge_target_data_in_valid;
    logic         bridge_target_rw;
    logic [7:0]   bridge_target_data_out;
    logic         bridge_target_data_out_valid;
    logic         bridge_target_ack;
    logic         bridge_target_ready;
    logic         bridge_target_split_ack;
    logic         bridge_target_req;
    logic         bridge_target_grant;
    logic [7:0]   bridge_target_last_write;

    initiator #(
        .WRITE_ADDR(REMOTE_TARGET_ADDR),
        .READ_ADDR(REMOTE_TARGET_ADDR),
        .MEM_INIT_DATA(LOCAL_INIT_WRITE)
    ) u_initiator_local (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(local_trigger_pulse),
        .init_grant(init_local_grant),
        .init_ack(init_local_ack),
        .init_split_ack(init_local_split_ack),
        .init_data_in(init_local_data_in),
        .init_data_in_valid(init_local_data_in_valid),
        .init_req(init_local_req),
        .init_addr_out(init_local_addr_out),
        .init_addr_out_valid(init_local_addr_out_valid),
        .init_data_out(init_local_data_out),
        .init_data_out_valid(init_local_data_out_valid),
        .init_rw(init_local_rw),
        .init_ready(init_local_ready),
        .done(),
        .read_data_value()
    );

    bus_bridge_initiator_uart_wrapper u_bridge_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(bridge_initiator_uart_rx),
        .uart_tx(bridge_initiator_uart_tx),
        .init_req(init_bridge_req),
        .init_addr_out(init_bridge_addr_out),
        .init_addr_out_valid(init_bridge_addr_out_valid),
        .init_data_out(init_bridge_data_out),
        .init_data_out_valid(init_bridge_data_out_valid),
        .init_rw(init_bridge_rw),
        .init_ready(init_bridge_ready),
        .init_grant(init_bridge_grant),
        .init_data_in(init_bridge_data_in),
        .init_data_in_valid(init_bridge_data_in_valid),
        .init_ack(init_bridge_ack),
        .init_split_ack(init_bridge_split_ack)
    );

    logic [7:0] target0_last_write;

    target #(
        .INTERNAL_ADDR_BITS(11)
    ) u_target0 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target0_addr_in),
        .target_addr_in_valid(target0_addr_in_valid),
        .target_data_in(target0_data_in),
        .target_data_in_valid(target0_data_in_valid),
        .target_rw(target0_rw),
        .target_data_out(target0_data_out),
        .target_data_out_valid(target0_data_out_valid),
        .target_ack(target0_ack),
        .target_ready(target0_ready),
        .target_last_write(target0_last_write)
    );

    target #(
        .INTERNAL_ADDR_BITS(12)
    ) u_target1 (
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

    bus_bridge_target_uart_wrapper #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(BRIDGE_TARGET0_SIZE),
        .TARGET1_SIZE(BRIDGE_TARGET1_SIZE),
        .TARGET2_SIZE(BRIDGE_TARGET2_SIZE),
        .BUSB_TARGET0_BASE(16'h8000),
        .BUSB_TARGET1_BASE(16'h0000),
        .BUSB_TARGET2_BASE(16'h4000)
    ) u_bridge_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(bridge_target_grant),
        .target_addr_in(bridge_target_addr_in),
        .target_addr_in_valid(bridge_target_addr_in_valid),
        .target_data_in(bridge_target_data_in),
        .target_data_in_valid(bridge_target_data_in_valid),
        .target_rw(bridge_target_rw),
        .split_req(bridge_target_req),
        .target_data_out(bridge_target_data_out),
        .target_data_out_valid(bridge_target_data_out_valid),
        .target_ack(bridge_target_ack),
        .target_split_ack(bridge_target_split_ack),
        .target_ready(bridge_target_ready),
        .split_target_last_write(bridge_target_last_write),
        .uart_tx(bridge_target_uart_tx),
        .uart_rx(bridge_target_uart_rx)
    );

    bus #(
        .TARGET1_BASE(TARGET0_BASE),
        .TARGET1_SIZE(TARGET0_SIZE),
        .TARGET2_BASE(TARGET1_BASE),
        .TARGET2_SIZE(TARGET1_SIZE),
        .TARGET3_BASE(BRIDGE_BASE_ADDR),
        .TARGET3_SIZE(BRIDGE_TOTAL_SPAN)
    ) system_bus (
        .clk(clk),
        .rst_n(rst_n),
        // Initiator 1: local push-button initiator.
        .init1_req(init_local_req),
        .init1_data_out(init_local_data_out),
        .init1_data_out_valid(init_local_data_out_valid),
        .init1_addr_out(init_local_addr_out),
        .init1_addr_out_valid(init_local_addr_out_valid),
        .init1_rw(init_local_rw),
        .init1_ready(init_local_ready),
        .init1_grant(init_local_grant),
        .init1_data_in(init_local_data_in),
        .init1_data_in_valid(init_local_data_in_valid),
        .init1_ack(init_local_ack),
        .init1_split_ack(init_local_split_ack),
        // Initiator 2: bridge UART initiator interface.
        .init2_req(init_bridge_req),
        .init2_data_out(init_bridge_data_out),
        .init2_data_out_valid(init_bridge_data_out_valid),
        .init2_addr_out(init_bridge_addr_out),
        .init2_addr_out_valid(init_bridge_addr_out_valid),
        .init2_rw(init_bridge_rw),
        .init2_ready(init_bridge_ready),
        .init2_grant(init_bridge_grant),
        .init2_data_in(init_bridge_data_in),
        .init2_data_in_valid(init_bridge_data_in_valid),
        .init2_ack(init_bridge_ack),
        .init2_split_ack(init_bridge_split_ack),
        // Target slot 1
        .target1_ready(target0_ready),
        .target1_ack(target0_ack),
        .target1_data_out(target0_data_out),
        .target1_data_out_valid(target0_data_out_valid),
        .target1_addr_in(target0_addr_in),
        .target1_addr_in_valid(target0_addr_in_valid),
        .target1_data_in(target0_data_in),
        .target1_data_in_valid(target0_data_in_valid),
        .target1_rw(target0_rw),
        // Target slot 2
        .target2_ready(target1_ready),
        .target2_ack(target1_ack),
        .target2_data_out(target1_data_out),
        .target2_data_out_valid(target1_data_out_valid),
        .target2_addr_in(target1_addr_in),
        .target2_addr_in_valid(target1_addr_in_valid),
        .target2_data_in(target1_data_in),
        .target2_data_in_valid(target1_data_in_valid),
        .target2_rw(target1_rw),
        // Split target slot occupied by bridge target wrapper.
        .split_target_ready(bridge_target_ready),
        .split_target_ack(bridge_target_ack),
        .split_target_split_ack(bridge_target_split_ack),
        .split_target_data_out(bridge_target_data_out),
        .split_target_data_out_valid(bridge_target_data_out_valid),
        .split_target_req(bridge_target_req),
        .split_target_addr_in(bridge_target_addr_in),
        .split_target_addr_in_valid(bridge_target_addr_in_valid),
        .split_target_data_in(bridge_target_data_in),
        .split_target_data_in_valid(bridge_target_data_in_valid),
        .split_target_rw(bridge_target_rw),
        .split_target_grant(bridge_target_grant)
    );

    assign leds = target0_last_write;

endmodule
