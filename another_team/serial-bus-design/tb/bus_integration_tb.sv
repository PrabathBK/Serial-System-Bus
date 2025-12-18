`timescale 1ns/1ps

module bus_integration_tb;
    logic clk;
    logic rst_n;

    // Test parameters targeting split-capable slave (target 3 range 1000 xxxx xxxx xxxx)
    localparam bit [15:0] TARGET3_ADDR = 16'h800A;
    localparam bit [7:0] TARGET_WRITE_DATA = 8'h6D;
    localparam int SPLIT_READ_LATENCY = 4;

    // Initiator 1 wiring
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

    // Initiator 2 wiring (kept idle)
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

    // Target 1 wiring
    logic [15:0]  target1_addr_in;
    logic         target1_addr_in_valid;
    logic [7:0]   target1_data_in;
    logic         target1_data_in_valid;
    logic         target1_rw;
    logic [7:0]   target1_data_out;
    logic         target1_data_out_valid;
    logic         target1_ack;
    logic         target1_ready;
    logic [7:0]   target1_last_write;

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
    logic [7:0]   target2_last_write;

    // Split target wiring (target 3)
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

    // Instantiate initiators
    initiator #(
        .WRITE_ADDR(TARGET3_ADDR),
        .READ_ADDR(TARGET3_ADDR),
        .MEM_INIT_DATA(TARGET_WRITE_DATA)
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

    initiator u_initiator_2 (
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
        .READ_LATENCY(SPLIT_READ_LATENCY)
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
        // Split target (target 3)
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

    // Scoreboard counters
    bit target1_accessed;
    bit target2_accessed;
    int split_write_ack_count;
    int split_read_ack_count;
    int split_ack_count;
    int init1_data_in_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target1_accessed <= 1'b0;
            target2_accessed <= 1'b0;
            split_write_ack_count <= 0;
            split_read_ack_count <= 0;
            split_ack_count <= 0;
            init1_data_in_count <= 0;
        end else begin
            if (target1_addr_in_valid)
                target1_accessed <= 1'b1;
            if (target2_addr_in_valid)
                target2_accessed <= 1'b1;
            if (split_target_ack && split_target_rw)
                split_write_ack_count <= split_write_ack_count + 1;
            else if (split_target_ack && !split_target_rw)
                split_read_ack_count <= split_read_ack_count + 1;
            if (split_target_split_ack)
                split_ack_count <= split_ack_count + 1;
            if (init1_data_in_valid)
                init1_data_in_count <= init1_data_in_count + 1;
        end
    end

    // Track final read data captured by initiator 1
    logic [7:0] init1_read_data;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init1_read_data <= '0;
        end else if (init1_data_in_valid) begin
            init1_read_data <= init1_data_in;
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

        // Fire initiator 1 sequence (write then read to split target)
        @(posedge clk);
        init1_trigger <= 1'b1;
        @(posedge clk);
        init1_trigger <= 1'b0;

        // Leave initiator 2 idle
        init2_trigger <= 1'b0;

        wait (init1_done);
        repeat (5) @(posedge clk);

        if (init1_data_in_count != 1)
            $error("Initiator 1 should observe exactly one data-valid pulse, saw %0d", init1_data_in_count);
        if (split_write_ack_count != 1)
            $error("Unexpected split-target write ACK count %0d", split_write_ack_count);
        if (split_read_ack_count != 1)
            $error("Unexpected split-target read ACK count %0d", split_read_ack_count);
        if (split_ack_count != 1)
            $error("Unexpected split-target split-ack count %0d", split_ack_count);
        if (target1_accessed)
            $error("Target 1 should not be accessed during this scenario");
        if (target2_accessed)
            $error("Target 2 should not be accessed during this scenario");
        if (init1_read_data !== TARGET_WRITE_DATA)
            $error("Read data mismatch. Expected %h, got %h", TARGET_WRITE_DATA, init1_read_data);

        $display("[%0t] Bus integration test completed successfully.", $time);
        $finish;
    end
endmodule
