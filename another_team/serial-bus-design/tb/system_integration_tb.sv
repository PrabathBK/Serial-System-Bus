`timescale 1ns/1ps

module system_integration_tb;
    // Clock and reset
    logic clk;
    logic rst_n;

    // Initiator stimulus
    logic init_req;
    logic [7:0] init_data_out;
    logic init_data_out_valid;
    logic [15:0] init_addr_out;
    logic init_addr_out_valid;
    logic init_rw;
    logic init_ready;
    logic target_split;
    logic target_ack;
    logic trigger;
    logic done;
    logic [7:0] read_data_value;

    // Initiator outputs / bus lines
    logic bus_serial;
    logic bus_serial_valid;
    logic bus_mode;
    logic init_grant;
    logic [7:0] init_data_in;
    logic init_data_in_valid;
    logic arbiter_req;
    logic init_ack;
    logic bus_init_ready;
    logic bus_init_rw;
    logic init_split_ack;

    // Connections to arbiter
    logic arbiter_grant;

    // Target port facing signals
    logic bus_data_out_from_target;
    logic bus_data_out_valid_from_target;
    logic [7:0] target_data_in;
    logic target_data_in_valid;
    logic [15:0] target_addr_in;
    logic target_addr_in_valid;
    logic bus_target_ready;
    logic bus_target_rw;
    logic bus_split_ack;
    logic bus_target_ack;
    logic arbiter_split_req;

    // Target core side signals
    logic split_req;
    logic split_grant;
    logic [7:0] target_data_out;
    logic target_data_out_valid;
    logic target_ready;
    logic target_split_ack;
    logic target_rw_dir;
    logic [7:0] split_target_last_write;

    // Address decoder outputs
    logic target_1_valid;
    logic target_2_valid;
    logic target_3_valid;
    logic [1:0] sel;
    logic [2:0] decoder_release_valids;

    // Constants for the scenario (choose address in Slave 3 range 1000 xxxx xxxx xxxx)
    localparam bit [15:0] TARGET3_ADDR = 16'h800A;
    localparam bit [7:0] TARGET_WRITE_DATA = 8'h5C;

    // Initiator core
    initiator #(
        .WRITE_ADDR(TARGET3_ADDR),
        .READ_ADDR(TARGET3_ADDR),
        .MEM_INIT_DATA(TARGET_WRITE_DATA)
    ) u_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(trigger),
        .init_grant(init_grant),
        .init_ack(init_ack),
        .init_split_ack(init_split_ack),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .init_req(init_req),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .done(done),
        .read_data_value(read_data_value)
    );

    // Instantiate initiator port
    init_port u_init_port (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init_req),
        .arbiter_grant(arbiter_grant),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .target_split(target_split),
        .target_ack(target_ack),
        .bus_data_in_valid(bus_data_out_valid_from_target),
        .bus_data_in(bus_data_out_from_target),
        .bus_data_out(bus_serial),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .bus_data_out_valid(bus_serial_valid),
        .arbiter_req(arbiter_req),
        .bus_mode(bus_mode),
        .init_ack(init_ack),
        .bus_init_ready(bus_init_ready),
        .bus_init_rw(bus_init_rw),
        .init_split_ack(init_split_ack)
    );

    // Instantiate split target port (receives serial stream)
    split_target_port u_split_target_port (
        .clk(clk),
        .rst_n(rst_n),
        .split_req(split_req),
        .arbiter_grant(arbiter_grant),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_rw(target_rw_dir),
        .target_ready(target_ready),
        .target_split_ack(target_split_ack),
        .target_ack(target_ack),
        .decoder_valid(target_3_valid),
        .bus_data_in_valid(bus_serial_valid),
        .bus_data_in(bus_serial),
        .bus_mode(bus_mode),
        .bus_data_out(bus_data_out_from_target),
        .split_grant(split_grant),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .bus_data_out_valid(bus_data_out_valid_from_target),
        .arbiter_split_req(arbiter_split_req),
        .split_ack(),
        .bus_target_ready(bus_target_ready),
        .bus_target_rw(bus_target_rw),
        .bus_split_ack(bus_split_ack),
        .bus_target_ack(bus_target_ack)
    );

    assign target_split = bus_split_ack;
    assign target_rw_dir = bus_init_rw;

    split_target #(
        .INTERNAL_ADDR_BITS(12),
        .READ_LATENCY(4)
    ) u_split_target (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_grant),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_rw(target_rw_dir),
        .split_req(split_req),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_ack(target_ack),
        .target_split_ack(target_split_ack),
        .target_ready(target_ready),
        .split_target_last_write(split_target_last_write)
    );

    // Instantiate address decoder observing the same bus
    addr_decoder u_addr_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .bus_data_in(bus_serial),
        .bus_data_in_valid(bus_serial_valid),
        .bus_mode(bus_mode),
        .release_valids(decoder_release_valids),
        .target_1_valid(target_1_valid),
        .target_2_valid(target_2_valid),
        .target_3_valid(target_3_valid),
        .sel(sel)
    );

    assign decoder_release_valids = {bus_target_ack, 2'b00};

    // Instantiate arbiter, only request/grant 1 used
    logic arbiter_grant_i1;
    logic arbiter_grant_split;

    arbiter u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_i_1(arbiter_req),
        .req_i_2(1'b0),
        .req_split(arbiter_split_req),
        .grant_i_1(arbiter_grant_i1),
        .grant_i_2(),
        .grant_split(arbiter_grant_split),
        .sel()
    );

    assign arbiter_grant = arbiter_grant_i1 | arbiter_grant_split;

    // Clock generation (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    bit decoder_target3_seen_write;
    bit decoder_target3_seen_read;
    bit decoder_wrong_target_seen;
    bit in_read_phase;
    int init_data_in_valid_count;
    int write_ack_count;
    int read_ack_count;
    int split_ack_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decoder_target3_seen_write <= 1'b0;
            decoder_target3_seen_read <= 1'b0;
            decoder_wrong_target_seen <= 1'b0;
            in_read_phase <= 1'b0;
            init_data_in_valid_count <= 0;
        end else begin
            if (init_split_ack)
                in_read_phase <= 1'b1;
            else if (done)
                in_read_phase <= 1'b0;

            if (target_3_valid && sel == 2'b10) begin
                if (in_read_phase)
                    decoder_target3_seen_read <= 1'b1;
                else
                    decoder_target3_seen_write <= 1'b1;
            end
            if (target_1_valid || target_2_valid || (target_3_valid && sel != 2'b10))
                decoder_wrong_target_seen <= 1'b1;
            if (init_split_ack)
                init_data_in_valid_count <= 0;
            else if (init_data_in_valid)
                init_data_in_valid_count <= init_data_in_valid_count + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ack_count <= 0;
            read_ack_count <= 0;
            split_ack_count <= 0;
        end else begin
            if (bus_target_ack && bus_target_rw)
                write_ack_count <= write_ack_count + 1;
            else if (bus_target_ack && !bus_target_rw)
                read_ack_count <= read_ack_count + 1;

            if (bus_split_ack)
                split_ack_count <= split_ack_count + 1;
        end
    end

    // Display target activity once both address and data arrive together
    always @(posedge clk) begin
        if (target_addr_in_valid && target_data_in_valid) begin
            $display("[%0t] Target observed %s to addr %h with data %h", $time,
                     bus_target_rw ? "WRITE" : "READ",
                     target_addr_in,
                     target_data_in);
        end
    end

    always @(posedge clk) begin
        if (init_data_in_valid) begin
            $display("[%0t] Initiator received data %h", $time, init_data_in);
        end
    end

    initial begin
        trigger = 1'b0;

        reset_dut();

        @(posedge clk);
        trigger <= 1'b1;
        @(posedge clk);
        trigger <= 1'b0;

        wait (done);

        if (!decoder_target3_seen_write)
            $error("Address decoder never asserted target 3 valid during write phase");

        if (!decoder_target3_seen_read)
            $error("Address decoder did not indicate target 3 during read phase");

        if (decoder_wrong_target_seen)
            $error("Address decoder asserted an unexpected target selection");

        if (write_ack_count != 1)
            $error("Unexpected number of write ACK pulses: %0d", write_ack_count);

        if (read_ack_count != 1)
            $error("Unexpected number of read ACK pulses: %0d", read_ack_count);

        if (split_ack_count != 1)
            $error("Unexpected number of split acknowledgements: %0d", split_ack_count);

        if (init_data_in_valid_count != 1)
            $error("Initiator should have seen exactly one data-valid pulse during read, observed %0d", init_data_in_valid_count);

        if (read_data_value !== TARGET_WRITE_DATA)
            $error("Read data mismatch. Expected %h, got %h", TARGET_WRITE_DATA, read_data_value);

        repeat (5) @(posedge clk);

        $display("[%0t] System integration test completed.", $time);
        $finish;
    end

endmodule
