`timescale 1ns/1ps

module bus_dual_transaction_tb;
    logic clk;
    logic rst_n;

    localparam bit [15:0] TARGET2_ADDR = 16'h4004;
    localparam bit [15:0] TARGET3_ADDR = 16'h8004;
    localparam bit [7:0] TARGET2_WRITE_DATA = 8'hA7;
    localparam bit [7:0] TARGET3_WRITE_DATA = 8'h5E;

    // Initiator 1 wiring (targets slave 2)
    logic         init1_trigger;
    logic         init1_done;
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

    // Initiator 2 wiring (targets slave 1)
    logic         init2_trigger;
    logic         init2_done;
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
    logic [7:0]   target1_last_write;

    // Target 1 wiring
    logic [15:0]  target1_addr_in;
    logic         target1_addr_in_valid;
    logic [7:0]   target1_data_in;
    logic         target1_data_in_valid;
    logic         target1_rw;
    logic [7:0]   target1_data_out;
    logic         target1_data_out_valid;
    logic         target1_ack;
    logic [7:0]   target2_last_write;
    logic         target1_ready;

    // Target 2 wiring
    logic [15:0]  target2_addr_in;
    logic         target2_addr_in_valid;
    logic [7:0]   target2_data_in;
    logic         target2_data_in_valid;
    logic         target2_rw;
    logic [7:0]   target2_data_out;
    logic         target2_data_out_valid;
    logic         target2_ack;
    logic         target2_ready;

    logic [7:0] split_target_last_write;
    // Split target wiring (kept idle)
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

    // Instantiate initiators
    initiator #(
        .WRITE_ADDR(TARGET2_ADDR),
        .READ_ADDR(TARGET2_ADDR),
        .MEM_INIT_DATA(TARGET2_WRITE_DATA)
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
        .read_data_value()
    );

    initiator #(
        .WRITE_ADDR(TARGET3_ADDR),
        .READ_ADDR(TARGET3_ADDR),
        .MEM_INIT_DATA(TARGET3_WRITE_DATA)
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
        .read_data_value()
    );

    // Instantiate targets
    target #(.INTERNAL_ADDR_BITS(11)) u_target_1 (
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

    target #(.INTERNAL_ADDR_BITS(11)) u_target_2 (
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

    // Device under test
    bus u_bus (
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

    // Clock generation (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Scoreboard state
    bit target1_write_seen;
    bit target1_read_seen;
    bit target2_write_seen;
    bit target2_read_seen;
    bit split_target_write_seen;
    bit split_target_read_seen;
    bit split_target_split_ack_seen;
    bit split_target_data_out_seen;
    int init1_data_in_count;
    int init2_data_in_count;

    logic [7:0] init1_read_data;
    logic [7:0] init2_read_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target1_write_seen <= 1'b0;
            target1_read_seen <= 1'b0;
            target2_write_seen <= 1'b0;
            target2_read_seen <= 1'b0;
            split_target_write_seen <= 1'b0;
            split_target_read_seen <= 1'b0;
            split_target_split_ack_seen <= 1'b0;
            split_target_data_out_seen <= 1'b0;
            init1_data_in_count <= 0;
            init2_data_in_count <= 0;
            init1_read_data <= '0;
            init2_read_data <= '0;
        end else begin
            if (target1_addr_in_valid && target1_rw)
                target1_write_seen <= 1'b1;
            if (target1_addr_in_valid && !target1_rw)
                target1_read_seen <= 1'b1;

            if (target2_addr_in_valid && target2_rw)
                target2_write_seen <= 1'b1;
            if (target2_addr_in_valid && !target2_rw)
                target2_read_seen <= 1'b1;

            if (split_target_addr_in_valid && split_target_rw)
                split_target_write_seen <= 1'b1;
            if (split_target_addr_in_valid && !split_target_rw)
                split_target_read_seen <= 1'b1;
            if (split_target_split_ack)
                split_target_split_ack_seen <= 1'b1;
            if (split_target_data_out_valid)
                split_target_data_out_seen <= 1'b1;

            if (init1_data_in_valid) begin
                init1_data_in_count <= init1_data_in_count + 1;
                init1_read_data <= init1_data_in;
            end

            if (init2_data_in_valid) begin
                init2_data_in_count <= init2_data_in_count + 1;
                init2_read_data <= init2_data_in;
            end
        end
    end

    // Reset task
    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    initial begin
        init1_trigger = 1'b0;
        init2_trigger = 1'b0;

        reset_dut();

        // Optional simultaneous request (both initiators)
        // To enable, assert init1_trigger and init2_trigger on the same clock edge
        // @(posedge clk);
        // init1_trigger <= 1'b1;
        // init2_trigger <= 1'b1;
        // @(posedge clk);
        // init1_trigger <= 1'b0;
        // init2_trigger <= 1'b0;
        // wait (init1_done);
        // wait (init2_done);

        // Transaction 1: initiator 2 to target 1
        @(posedge clk);
        init2_trigger <= 1'b1;
        @(posedge clk);
        init2_trigger <= 1'b0;
        wait (init2_done);

        // Allow bus to settle before second transaction
        repeat (10) @(posedge clk);

        // Transaction 2: initiator 1 to target 2
        init1_trigger <= 1'b1;
        @(posedge clk);
        init1_trigger <= 1'b0;
        wait (init1_done);
        repeat (10) @(posedge clk);

        // Checks for transaction 1 (initiator 2 -> split target)
        if (!split_target_write_seen)
            $error("Split target write was not observed");
        if (!split_target_read_seen)
            $error("Split target read was not observed");
        if (!split_target_split_ack_seen)
            $error("Split target split-ack was not observed");
        if (!split_target_data_out_seen)
            $error("Split target read data was not observed");
        if (target1_write_seen || target1_read_seen)
            $error("Target 1 should remain idle during split target transaction");
        if (init2_data_in_count != 1)
            $error("Initiator 2 should observe exactly one data-valid pulse, saw %0d", init2_data_in_count);
        if (init2_read_data !== TARGET3_WRITE_DATA)
            $error("Initiator 2 read data mismatch. Expected %h, got %h", TARGET3_WRITE_DATA, init2_read_data);

        // Checks for transaction 2
        if (!target2_write_seen)
            $error("Target 2 write was not observed");
        if (!target2_read_seen)
            $error("Target 2 read was not observed");
        if (init1_data_in_count != 1)
            $error("Initiator 1 should observe exactly one data-valid pulse, saw %0d", init1_data_in_count);
        if (init1_read_data !== TARGET2_WRITE_DATA)
            $error("Initiator 1 read data mismatch. Expected %h, got %h", TARGET2_WRITE_DATA, init1_read_data);

        $display("[%0t] Dual-transaction bus integration test completed successfully.", $time);
        $finish;
    end
endmodule
