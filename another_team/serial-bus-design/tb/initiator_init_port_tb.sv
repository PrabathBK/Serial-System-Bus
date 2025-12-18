`timescale 1ns/1ps

module initiator_init_port_tb;
    logic clk;
    logic rst_n;

    localparam bit [15:0] WRITE_ADDR = 16'h0012;
    localparam bit [7:0] WRITE_DATA = 8'h3C;
    localparam bit [15:0] READ_ADDR = 16'h0034;
    localparam bit [7:0] READ_RESP = 8'h96;
    localparam int READ_DELAY_CYCLES = 4;

    logic init_req;
    logic [15:0] init_addr_out;
    logic init_addr_out_valid;
    logic [7:0] init_data_out;
    logic init_data_out_valid;
    logic init_rw;
    logic init_ready;
    logic init_grant;
    logic [7:0] init_data_in;
    logic init_data_in_valid;
    logic bus_data_out;
    logic bus_data_out_valid;
    logic arbiter_req;
    logic bus_mode;
    logic init_ack;
    logic bus_init_ready;
    logic bus_init_rw;
    logic init_split_ack;
    logic bus_data_in;
    logic bus_data_in_valid;
    logic target_split;
    logic target_ack;
    logic arbiter_grant;
    logic init_done;
    logic [7:0] read_data_value;
    logic trigger;
    logic write_done_pulse;
    logic read_cmd_pulse;
    logic read_resp_pulse;
    int write_ack_count;
    int read_ack_count;
    int split_ack_count;

    initiator #(
        .WRITE_ADDR(WRITE_ADDR),
        .READ_ADDR(READ_ADDR),
        .MEM_INIT_DATA(WRITE_DATA)
    ) u_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init_req),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .trigger(trigger),
        .init_grant(init_grant),
        .init_ack(init_ack),
        .init_split_ack(init_split_ack),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .done(init_done),
        .read_data_value(read_data_value)
    );

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
        .bus_data_in_valid(bus_data_in_valid),
        .bus_data_in(bus_data_in),
        .bus_data_out(bus_data_out),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .bus_data_out_valid(bus_data_out_valid),
        .arbiter_req(arbiter_req),
        .bus_mode(bus_mode),
        .init_ack(init_ack),
        .bus_init_ready(bus_init_ready),
        .bus_init_rw(bus_init_rw),
        .init_split_ack(init_split_ack)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            arbiter_grant <= 1'b0;
        else
            arbiter_grant <= arbiter_req;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_ack <= 1'b0;
            target_split <= 1'b0;
        end else begin
            target_ack <= 1'b0;
            target_split <= 1'b0;

            if (write_done_pulse)
                target_ack <= 1'b1;

            if (read_cmd_pulse)
                target_split <= 1'b1;

            if (read_resp_pulse)
                target_ack <= 1'b1;
        end
    end

    logic [15:0] addr_shift;
    logic [4:0] addr_cnt;
    logic [7:0] data_shift;
    logic [3:0] data_cnt;
    logic [15:0] write_addr_captured;
    logic [15:0] read_addr_captured;
    logic [7:0] write_data_captured;
    logic write_addr_valid;
    logic read_addr_valid;
    logic write_phase_active;
    logic read_cmd_pending;
    logic clear_read_cmd;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_shift <= '0;
            addr_cnt <= '0;
            data_shift <= '0;
            data_cnt <= '0;
            write_addr_captured <= '0;
            read_addr_captured <= '0;
            write_data_captured <= '0;
            write_addr_valid <= 1'b0;
            read_addr_valid <= 1'b0;
            write_phase_active <= 1'b0;
            read_cmd_pending <= 1'b0;
            write_done_pulse <= 1'b0;
            read_cmd_pulse <= 1'b0;
        end else begin
            logic read_cmd_set;
            read_cmd_set = 1'b0;

            write_done_pulse <= 1'b0;
            read_cmd_pulse <= 1'b0;

            if (bus_data_out_valid && (bus_mode == 1'b0)) begin
                logic [15:0] next_addr;
                next_addr = {bus_data_out, addr_shift[15:1]};
                addr_shift <= next_addr;

                if (addr_cnt == 5'd15) begin
                    addr_cnt <= 5'd0;

                    if (bus_init_rw) begin
                        write_addr_captured <= next_addr;
                        write_addr_valid <= 1'b1;
                        write_phase_active <= 1'b1;
                        data_cnt <= 4'd0;
                        data_shift <= '0;
                    end else begin
                        read_addr_captured <= next_addr;
                        read_addr_valid <= 1'b1;
                        read_cmd_set = 1'b1;
                    end
                end else begin
                    addr_cnt <= addr_cnt + 5'd1;
                end
            end else if (bus_data_out_valid && (bus_mode == 1'b1) && write_phase_active) begin
                logic [7:0] next_data;
                next_data = {bus_data_out, data_shift[7:1]};
                data_shift <= next_data;

                if (data_cnt == 4'd7) begin
                    write_data_captured <= next_data;
                    write_phase_active <= 1'b0;
                    data_cnt <= 4'd0;
                    write_done_pulse <= 1'b1;
                end else begin
                    data_cnt <= data_cnt + 4'd1;
                end
            end

            if (clear_read_cmd)
                read_cmd_pending <= 1'b0;
            else if (read_cmd_set)
                read_cmd_pending <= 1'b1;

            if (read_cmd_set && READ_DELAY_CYCLES != 0)
                read_cmd_pulse <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ack_count <= 0;
            read_ack_count <= 0;
            split_ack_count <= 0;
        end else begin
            if (target_ack && bus_init_rw)
                write_ack_count <= write_ack_count + 1;
            else if (target_ack && !bus_init_rw)
                read_ack_count <= read_ack_count + 1;

            if (target_split)
                split_ack_count <= split_ack_count + 1;
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            if (target_ack && bus_init_rw && !init_ack)
                $error("Write acknowledgement not forwarded to initiator");
            if (init_ack && bus_init_rw && !target_ack)
                $error("Initiator observed write ACK without target asserting ack");
            if (init_ack && !bus_init_rw && !init_data_in_valid)
                $error("Read acknowledgement arrived without data valid");
            if (init_data_in_valid && !init_ack)
                $error("Read data valid without acknowledgement");
            if (init_split_ack !== target_split)
                $error("init_split_ack pass-through mismatch");
        end
    end

    typedef enum logic [1:0] {
        RESP_IDLE,
        RESP_WAIT,
        RESP_SEND
    } resp_state_t;

    resp_state_t resp_state;
    logic [3:0] resp_bit_cnt;
    logic [3:0] resp_wait_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_state <= RESP_IDLE;
            resp_bit_cnt <= 4'd0;
            resp_wait_cnt <= 4'd0;
            bus_data_in_valid <= 1'b0;
            bus_data_in <= 1'b0;
            clear_read_cmd <= 1'b0;
            read_resp_pulse <= 1'b0;
        end else begin
            bus_data_in_valid <= 1'b0;
            clear_read_cmd <= 1'b0;
            read_resp_pulse <= 1'b0;

            case (resp_state)
                RESP_IDLE: begin
                    bus_data_in <= 1'b0;
                    resp_bit_cnt <= 4'd0;
                    resp_wait_cnt <= 4'd0;

                    if (read_cmd_pending && (bus_mode == 1'b1) && !bus_data_out_valid) begin
                        if (READ_DELAY_CYCLES == 0) begin
                            resp_state <= RESP_SEND;
                        end else begin
                            resp_state <= RESP_WAIT;
                            resp_wait_cnt <= READ_DELAY_CYCLES[3:0] - 4'd1;
                        end
                    end
                end
                RESP_WAIT: begin
                    bus_data_in <= 1'b0;

                    if (resp_wait_cnt == 4'd0) begin
                        resp_state <= RESP_SEND;
                        resp_bit_cnt <= 4'd0;
                    end else begin
                        resp_wait_cnt <= resp_wait_cnt - 4'd1;
                    end
                end
                RESP_SEND: begin
                    bus_data_in_valid <= 1'b1;
                    bus_data_in <= READ_RESP[resp_bit_cnt];

                    if (resp_bit_cnt == 4'd7) begin
                        resp_state <= RESP_IDLE;
                        clear_read_cmd <= 1'b1;
                        read_resp_pulse <= 1'b1;
                    end else begin
                        resp_bit_cnt <= resp_bit_cnt + 4'd1;
                    end
                end
            endcase
        end
    end

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
    rst_n = 1'b0;
    trigger = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        repeat (3) @(posedge clk);
        trigger = 1'b1;
        @(posedge clk);
        trigger = 1'b0;

        wait (init_done);
        repeat (4) @(posedge clk);

        if (!write_addr_valid || write_addr_captured !== WRITE_ADDR)
            $error("Write address mismatch. Expected %h, got %h", WRITE_ADDR, write_addr_captured);

        if (write_data_captured !== WRITE_DATA)
            $error("Write data mismatch. Expected %h, got %h", WRITE_DATA, write_data_captured);

        if (!read_addr_valid || read_addr_captured !== READ_ADDR)
            $error("Read address mismatch. Expected %h, got %h", READ_ADDR, read_addr_captured);

        if (read_data_value !== READ_RESP)
            $error("Initiator stored wrong read data. Expected %h, got %h", READ_RESP, read_data_value);

        if (bus_init_ready !== init_ready)
            $error("Ready pass-through mismatch");

        if (bus_init_rw !== init_rw)
            $error("RW pass-through mismatch");

        if (write_ack_count != 1)
            $error("Expected a single write ACK pulse, observed %0d", write_ack_count);

        if (read_ack_count != 1)
            $error("Expected a single read ACK pulse, observed %0d", read_ack_count);

        if (READ_DELAY_CYCLES != 0) begin
            if (split_ack_count != 1)
                $error("Expected one split acknowledge pulse, observed %0d", split_ack_count);
        end else if (split_ack_count != 0) begin
            $error("Target should not issue split acknowledge when delay is zero");
        end

        $display("[%0t] initiator-init_port integration test completed.", $time);
        $finish;
    end
endmodule
