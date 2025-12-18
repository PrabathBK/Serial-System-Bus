`timescale 1ns/1ps

module system_top_with_bus_bridge (
    input  logic        clk,
    input  logic        btn_reset,
    input  logic        btn_trigger,
    output logic [7:0]  leds
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
        if (!rst_n) begin
            trigger_sync_prev <= 1'b0;
        end else begin
            trigger_sync_prev <= trigger_sync_ff2;
        end
    end

    logic init1_trigger_pulse;
    assign init1_trigger_pulse = trigger_sync_ff2 & ~trigger_sync_prev;

    // Local parameters describing address map expectations.
    localparam bit [15:0] TARGET2_ADDR = 16'h4004;
    localparam bit [15:0] TARGET3_ADDR = 16'h8004;
    localparam bit [7:0]  TARGET3_INIT_WRITE = 8'hA5;
    localparam bit [7:0]  TARGET2_INIT_WRITE = 8'h5A;
    localparam bit [15:0] BRIDGE_BASE_ADDR = 16'h8000;
    localparam int unsigned BRIDGE_TARGET0_SIZE = 16'd4096;
    localparam int unsigned BRIDGE_TARGET1_SIZE = 16'd2048;
    localparam int unsigned BRIDGE_TARGET2_SIZE = 16'd4096;
    localparam int unsigned BRIDGE_ADDR_SPACE = BRIDGE_TARGET0_SIZE + BRIDGE_TARGET1_SIZE + BRIDGE_TARGET2_SIZE;

    // Initiator 1 wiring (active via push button trigger).
    logic         init1_req;
    logic [15:0]  init1_addr_out;
    logic         init1_addr_out_valid;
    logic [7:0]   init1_data_out;
    logic         init1_data_out_valid;
    logic         init1_rw;
    logic         init1_ready;
    logic         init1_grant;
    logic [7:0]   init1_data_in;
    logic         init1_data_in_valid;
    logic         init1_ack;
    logic         init1_split_ack;

    // Initiator 2 remains instantiated for completeness but stays idle.
    logic         init2_req;
    logic [15:0]  init2_addr_out;
    logic         init2_addr_out_valid;
    logic [7:0]   init2_data_out;
    logic         init2_data_out_valid;
    logic         init2_rw;
    logic         init2_ready;
    logic         init2_grant;
    logic [7:0]   init2_data_in;
    logic         init2_data_in_valid;
    logic         init2_ack;
    logic         init2_split_ack;

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

    // Split target (target 3) interface wires.
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

    // Bus bridge acting as an initiator on Bus B.
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

    // Bus B target interfaces.
    logic [15:0]  b_target1_addr_in;
    logic         b_target1_addr_in_valid;
    logic [7:0]   b_target1_data_in;
    logic         b_target1_data_in_valid;
    logic         b_target1_rw;
    logic [7:0]   b_target1_data_out;
    logic         b_target1_data_out_valid;
    logic         b_target1_ack;
    logic         b_target1_ready;

    logic [15:0]  b_target2_addr_in;
    logic         b_target2_addr_in_valid;
    logic [7:0]   b_target2_data_in;
    logic         b_target2_data_in_valid;
    logic         b_target2_rw;
    logic [7:0]   b_target2_data_out;
    logic         b_target2_data_out_valid;
    logic         b_target2_ack;
    logic         b_target2_ready;

    logic [15:0]  b_split_target_addr_in;
    logic         b_split_target_addr_in_valid;
    logic [7:0]   b_split_target_data_in;
    logic         b_split_target_data_in_valid;
    logic         b_split_target_rw;
    logic [7:0]   b_split_target_data_out;
    logic         b_split_target_data_out_valid;
    logic         b_split_target_ack;
    logic         b_split_target_ready;
    logic         b_split_target_split_ack;
    logic         b_split_target_req;
    logic         b_split_target_grant;
    logic [7:0]   b_split_target_last_write;

    // Unused bus B initiator outputs.
    logic         b_init2_grant;
    logic [7:0]   b_init2_data_in;
    logic         b_init2_data_in_valid;
    logic         b_init2_ack;
    logic         b_init2_split_ack;

    // Initiator instantiations.
    initiator #(
        .WRITE_ADDR(TARGET3_ADDR),
        .READ_ADDR(TARGET3_ADDR),
        .MEM_INIT_DATA(TARGET3_INIT_WRITE)
    ) u_initiator_1 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(init1_trigger_pulse),
        .init_grant(init1_grant),
        .init_ack(init1_ack),
        .init_split_ack(init1_split_ack),
        .init_data_in(init1_data_in),
        .init_data_in_valid(init1_data_in_valid),
        .init_req(init1_req),
        .init_addr_out(init1_addr_out),
        .init_addr_out_valid(init1_addr_out_valid),
        .init_data_out(init1_data_out),
        .init_data_out_valid(init1_data_out_valid),
        .init_rw(init1_rw),
        .init_ready(init1_ready),
        .done(),
        .read_data_value()
    );

    initiator #(
        .WRITE_ADDR(TARGET2_ADDR),
        .READ_ADDR(TARGET2_ADDR),
        .MEM_INIT_DATA(TARGET2_INIT_WRITE)
    ) u_initiator_2 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(1'b0),
        .init_grant(init2_grant),
        .init_ack(init2_ack),
        .init_split_ack(init2_split_ack),
        .init_data_in(init2_data_in),
        .init_data_in_valid(init2_data_in_valid),
        .init_req(init2_req),
        .init_addr_out(init2_addr_out),
        .init_addr_out_valid(init2_addr_out_valid),
        .init_data_out(init2_data_out),
        .init_data_out_valid(init2_data_out_valid),
        .init_rw(init2_rw),
        .init_ready(init2_ready),
        .done(),
        .read_data_value()
    );

    // Target instantiations.
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
        .INTERNAL_ADDR_BITS(11)
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

    bus_bridge #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(BRIDGE_TARGET0_SIZE),
        .TARGET1_SIZE(BRIDGE_TARGET1_SIZE),
        .TARGET2_SIZE(BRIDGE_TARGET2_SIZE),
        .BUSB_TARGET0_BASE(16'h8000),
        .BUSB_TARGET1_BASE(16'h0000),
        .BUSB_TARGET2_BASE(16'h4000)
    ) u_bus_bridge (
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
        .split_target_last_write(split_target_last_write),
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

    target #(
        .INTERNAL_ADDR_BITS(11)
    ) u_b_target_1 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(b_target1_addr_in),
        .target_addr_in_valid(b_target1_addr_in_valid),
        .target_data_in(b_target1_data_in),
        .target_data_in_valid(b_target1_data_in_valid),
        .target_rw(b_target1_rw),
        .target_data_out(b_target1_data_out),
        .target_data_out_valid(b_target1_data_out_valid),
        .target_ack(b_target1_ack),
        .target_ready(b_target1_ready),
        .target_last_write()
    );

    target #(
        .INTERNAL_ADDR_BITS(12)
    ) u_b_target_2 (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(b_target2_addr_in),
        .target_addr_in_valid(b_target2_addr_in_valid),
        .target_data_in(b_target2_data_in),
        .target_data_in_valid(b_target2_data_in_valid),
        .target_rw(b_target2_rw),
        .target_data_out(b_target2_data_out),
        .target_data_out_valid(b_target2_data_out_valid),
        .target_ack(b_target2_ack),
        .target_ready(b_target2_ready),
        .target_last_write()
    );

    split_target #(
        .INTERNAL_ADDR_BITS(12),
        .READ_LATENCY(4)
    ) u_b_split_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(b_split_target_grant),
        .target_addr_in(b_split_target_addr_in),
        .target_addr_in_valid(b_split_target_addr_in_valid),
        .target_data_in(b_split_target_data_in),
        .target_data_in_valid(b_split_target_data_in_valid),
        .target_rw(b_split_target_rw),
        .split_req(b_split_target_req),
        .target_data_out(b_split_target_data_out),
        .target_data_out_valid(b_split_target_data_out_valid),
        .target_ack(b_split_target_ack),
        .target_split_ack(b_split_target_split_ack),
        .target_ready(b_split_target_ready),
        .split_target_last_write(b_split_target_last_write)
    );

    // Bus interconnect.
    bus #(
        .TARGET3_BASE(BRIDGE_BASE_ADDR),
        .TARGET3_SIZE(BRIDGE_ADDR_SPACE)
    ) u_bus (
        .clk(clk),
        .rst_n(rst_n),
        // Initiator 1
        .init1_req(init1_req),
        .init1_data_out(init1_data_out),
        .init1_data_out_valid(init1_data_out_valid),
        .init1_addr_out(init1_addr_out),
        .init1_addr_out_valid(init1_addr_out_valid),
        .init1_rw(init1_rw),
        .init1_ready(init1_ready),
        .init1_grant(init1_grant),
        .init1_data_in(init1_data_in),
        .init1_data_in_valid(init1_data_in_valid),
        .init1_ack(init1_ack),
        .init1_split_ack(init1_split_ack),
        // Initiator 2
        .init2_req(init2_req),
        .init2_data_out(init2_data_out),
        .init2_data_out_valid(init2_data_out_valid),
        .init2_addr_out(init2_addr_out),
        .init2_addr_out_valid(init2_addr_out_valid),
        .init2_rw(init2_rw),
        .init2_ready(init2_ready),
        .init2_grant(init2_grant),
        .init2_data_in(init2_data_in),
        .init2_data_in_valid(init2_data_in_valid),
        .init2_ack(init2_ack),
        .init2_split_ack(init2_split_ack),
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

    bus u_bus_b (
        .clk(clk),
        .rst_n(rst_n),
        // Initiator 1 (bridge)
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
        .init2_grant(b_init2_grant),
        .init2_data_in(b_init2_data_in),
        .init2_data_in_valid(b_init2_data_in_valid),
        .init2_ack(b_init2_ack),
        .init2_split_ack(b_init2_split_ack),
        // Target 1
        .target1_ready(b_target1_ready),
        .target1_ack(b_target1_ack),
        .target1_data_out(b_target1_data_out),
        .target1_data_out_valid(b_target1_data_out_valid),
        .target1_addr_in(b_target1_addr_in),
        .target1_addr_in_valid(b_target1_addr_in_valid),
        .target1_data_in(b_target1_data_in),
        .target1_data_in_valid(b_target1_data_in_valid),
        .target1_rw(b_target1_rw),
        // Target 2
        .target2_ready(b_target2_ready),
        .target2_ack(b_target2_ack),
        .target2_data_out(b_target2_data_out),
        .target2_data_out_valid(b_target2_data_out_valid),
        .target2_addr_in(b_target2_addr_in),
        .target2_addr_in_valid(b_target2_addr_in_valid),
        .target2_data_in(b_target2_data_in),
        .target2_data_in_valid(b_target2_data_in_valid),
        .target2_rw(b_target2_rw),
        // Split target
        .split_target_ready(b_split_target_ready),
        .split_target_ack(b_split_target_ack),
        .split_target_split_ack(b_split_target_split_ack),
        .split_target_data_out(b_split_target_data_out),
        .split_target_data_out_valid(b_split_target_data_out_valid),
        .split_target_req(b_split_target_req),
        .split_target_addr_in(b_split_target_addr_in),
        .split_target_addr_in_valid(b_split_target_addr_in_valid),
        .split_target_data_in(b_split_target_data_in),
        .split_target_data_in_valid(b_split_target_data_in_valid),
        .split_target_rw(b_split_target_rw),
        .split_target_grant(b_split_target_grant)
    );

    // Drive LEDs with the most recent write observed by the split target.
    assign leds = b_split_target_last_write;

endmodule
