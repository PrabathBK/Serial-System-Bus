`timescale 1ns/1ps

module system_top_with_bus_bridge_dual_init_tb;
    localparam logic [15:0] INIT1_ADDR = 16'h8004;
    localparam logic [15:0] INIT2_ADDR = 16'h9004;
    localparam logic [7:0] INIT1_DATA = 8'hA5;
    localparam logic [7:0] INIT2_DATA = 8'h3C;
    localparam logic [15:0] TARGET1_BASE_ADDR = 16'h0000;
    localparam int unsigned TARGET1_SIZE = 16'd2048;
    localparam logic [15:0] TARGET2_BASE_ADDR = 16'h4000;
    localparam int unsigned TARGET2_SIZE = 16'd4096;
    localparam logic [15:0] BRIDGE_BASE_ADDR = 16'h8000;
    localparam int unsigned BRIDGE_TARGET0_SIZE = 16'd4096;
    localparam int unsigned BRIDGE_TARGET1_SIZE = 16'd2048;
    localparam int unsigned BRIDGE_TARGET2_SIZE = 16'd4096;
    localparam int unsigned BRIDGE_ADDR_SPACE = BRIDGE_TARGET0_SIZE + BRIDGE_TARGET1_SIZE + BRIDGE_TARGET2_SIZE;

    // Clock and reset.
    logic clk;
    logic rst_n;

    // Stimulus triggers for the initiators.
    logic init1_trigger;
    logic init2_trigger;

    // Initiator 1 signals.
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
    logic         init1_done;
    logic [7:0]   init1_read_data;

    // Initiator 2 signals.
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
    logic         init2_done;
    logic [7:0]   init2_read_data;

    // Bus A target interfaces.
    logic [15:0]  target1_addr_in;
    logic         target1_addr_in_valid;
    logic [7:0]   target1_data_in;
    logic         target1_data_in_valid;
    logic [7:0]   target1_data_out;
    logic         target1_data_out_valid;
    logic         target1_ack;
    logic         target1_ready;
    logic         target1_rw;
    logic [7:0]   target1_last_write;

    logic [15:0]  target2_addr_in;
    logic         target2_addr_in_valid;
    logic [7:0]   target2_data_in;
    logic         target2_data_in_valid;
    logic [7:0]   target2_data_out;
    logic         target2_data_out_valid;
    logic         target2_ack;
    logic         target2_ready;
    logic         target2_rw;
    logic [7:0]   target2_last_write;

    // Bus A split-target style wiring (terminates in the bridge).
    logic         split_target_ready;
    logic         split_target_ack;
    logic         split_target_split_ack;
    logic [7:0]   split_target_data_out;
    logic         split_target_data_out_valid;
    logic         split_target_req;
    logic [15:0]  split_target_addr_in;
    logic         split_target_addr_in_valid;
    logic [7:0]   split_target_data_in;
    logic         split_target_data_in_valid;
    logic         split_target_rw;
    logic         split_target_grant;
    logic [7:0]   split_target_last_write;

    // Bridge initiator side (Bus B interface).
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
    logic [7:0]   b_target1_data_out;
    logic         b_target1_data_out_valid;
    logic         b_target1_ack;
    logic         b_target1_ready;
    logic         b_target1_rw;
    logic [7:0]   b_target1_last_write;

    logic [15:0]  b_target2_addr_in;
    logic         b_target2_addr_in_valid;
    logic [7:0]   b_target2_data_in;
    logic         b_target2_data_in_valid;
    logic [7:0]   b_target2_data_out;
    logic         b_target2_data_out_valid;
    logic         b_target2_ack;
    logic         b_target2_ready;
    logic         b_target2_rw;
    logic [7:0]   b_target2_last_write;

    logic [15:0]  b_split_target_addr_in;
    logic         b_split_target_addr_in_valid;
    logic [7:0]   b_split_target_data_in;
    logic         b_split_target_data_in_valid;
    logic [7:0]   b_split_target_data_out;
    logic         b_split_target_data_out_valid;
    logic         b_split_target_ack;
    logic         b_split_target_ready;
    logic         b_split_target_split_ack;
    logic         b_split_target_req;
    logic         b_split_target_grant;
    logic [7:0]   b_split_target_last_write;

    // Unused Bus B initiator outputs.
    logic         b_init2_grant;
    logic [7:0]   b_init2_data_in;
    logic         b_init2_data_in_valid;
    logic         b_init2_ack;
    logic         b_init2_split_ack;

    // Tracking flags.
    logic init1_ack_seen;
    logic init2_ack_seen;
    logic init1_split_ack_seen;
    logic init2_split_ack_seen;

    // Clock generation.
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Reset and stimulus sequencing.
    initial begin
        rst_n = 1'b0;
        init1_trigger = 1'b0;
        init2_trigger = 1'b0;
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);
        init1_trigger = 1'b1;
        @(posedge clk);
        init1_trigger = 1'b0;
        wait (init1_done);

        repeat (4) @(posedge clk);
        init2_trigger = 1'b1;
        @(posedge clk);
        init2_trigger = 1'b0;
        wait (init2_done);

        @(posedge clk);
        if (init1_read_data !== INIT1_DATA)
            $error("Initiator 1 readback %02h, expected %02h", init1_read_data, INIT1_DATA);
        if (init2_read_data !== INIT2_DATA)
            $error("Initiator 2 readback %02h, expected %02h", init2_read_data, INIT2_DATA);
        if (!init1_ack_seen)
            $error("Initiator 1 never observed ACK");
        if (!init1_split_ack_seen)
            $error("Initiator 1 never observed split ACK");
        if (!init2_ack_seen)
            $error("Initiator 2 never observed ACK");
        if (init2_split_ack_seen)
            $error("Initiator 2 unexpectedly observed split ACK");
        if (b_split_target_last_write !== INIT1_DATA)
            $error("Bus B split target last write %02h, expected %02h", b_split_target_last_write, INIT1_DATA);
        if (b_target1_last_write !== INIT2_DATA)
            $error("Bus B target1 last write %02h, expected %02h", b_target1_last_write, INIT2_DATA);
        if (b_target2_last_write !== 8'h00)
            $display("INFO: Bus B target2 saw write %02h", b_target2_last_write);
        if (init1_read_data === INIT1_DATA && init2_read_data === INIT2_DATA && init1_ack_seen && init2_ack_seen && init1_split_ack_seen && !init2_split_ack_seen && b_split_target_last_write === INIT1_DATA && b_target1_last_write === INIT2_DATA)
            $display("[%0t] Dual-initiator bridge test PASSED", $time);
        else
            $display("[%0t] Dual-initiator bridge test completed with issues", $time);
        repeat (5) @(posedge clk);
        $finish;
    end

    // Timeout guard.
    initial begin
        #200000;
        $fatal(1, "Timeout waiting for dual-initiator bridge test to complete");
    end

    // Track acknowledgements.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init1_ack_seen <= 1'b0;
            init2_ack_seen <= 1'b0;
            init1_split_ack_seen <= 1'b0;
            init2_split_ack_seen <= 1'b0;
        end else begin
            if (init1_ack)
                init1_ack_seen <= 1'b1;
            if (init2_ack)
                init2_ack_seen <= 1'b1;
            if (init1_split_ack)
                init1_split_ack_seen <= 1'b1;
            if (init2_split_ack)
                init2_split_ack_seen <= 1'b1;
        end
    end

    // Initiator instances.
    initiator #(
        .WRITE_ADDR(INIT1_ADDR),
        .READ_ADDR(INIT1_ADDR),
        .MEM_INIT_DATA(INIT1_DATA)
    ) u_initiator_1 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(init1_trigger),
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
        .done(init1_done),
        .read_data_value(init1_read_data)
    );

    initiator #(
        .WRITE_ADDR(INIT2_ADDR),
        .READ_ADDR(INIT2_ADDR),
        .MEM_INIT_DATA(INIT2_DATA)
    ) u_initiator_2 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(init2_trigger),
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
        .done(init2_done),
        .read_data_value(init2_read_data)
    );

    // Target instances on Bus A (not directly exercised in this test).
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
        .target_last_write(target1_last_write)
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
        .target_last_write(target2_last_write)
    );

    // Bus bridge instance (acts as Bus A split target, Bus B initiator).
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

    // Bus B target instances.
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
        .target_last_write(b_target1_last_write)
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
        .target_last_write(b_target2_last_write)
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

    // Bus A interconnect.
    bus #(
        .TARGET1_BASE(TARGET1_BASE_ADDR),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_BASE(TARGET2_BASE_ADDR),
        .TARGET2_SIZE(TARGET2_SIZE),
        .TARGET3_BASE(BRIDGE_BASE_ADDR),
        .TARGET3_SIZE(BRIDGE_ADDR_SPACE)
    ) u_bus_a (
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
        // Split target (bridge)
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

    // Bus B interconnect.
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
endmodule
