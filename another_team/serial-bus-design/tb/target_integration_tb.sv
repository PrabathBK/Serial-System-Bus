`timescale 1ns/1ps

module target_integration_tb;
    logic clk;
    logic rst_n;

    localparam bit [15:0] WRITE_ADDR = 16'h0532;
    localparam bit [7:0] WRITE_DATA = 8'h9E;
    localparam bit [15:0] READ_ADDR  = WRITE_ADDR;

    logic [7:0] target_data_out;
    logic target_data_out_valid;
    logic target_rw;
    logic target_ready;
    logic target_ack;
    logic [7:0] target_last_write;

    logic bus_data_in;
    logic bus_data_in_valid;
    logic bus_mode;
    logic bus_data_out;
    logic bus_data_out_valid;
    logic [7:0] target_data_in;
    logic target_data_in_valid;
    logic [15:0] target_addr_in;
    logic target_addr_in_valid;
    logic bus_target_ready;
    logic bus_target_rw;
    logic bus_target_ack;
    logic decoder_valid;

    logic [7:0] read_back_serial;
    int write_ack_count;
    int read_ack_count;

    target #(
        .INTERNAL_ADDR_BITS(11)
    ) u_target (
        .clk(clk),
        .rst_n(rst_n),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_rw(target_rw),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_ack(target_ack),
        .target_ready(target_ready),
        .target_last_write(target_last_write)
    );

    target_port u_target_port (
        .clk(clk),
        .rst_n(rst_n),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_rw(target_rw),
        .target_ready(target_ready),
        .target_ack(target_ack),
        .decoder_valid(decoder_valid),
        .bus_data_in_valid(bus_data_in_valid),
        .bus_data_in(bus_data_in),
        .bus_mode(bus_mode),
        .bus_data_out(bus_data_out),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .bus_data_out_valid(bus_data_out_valid),
        .bus_target_ready(bus_target_ready),
        .bus_target_rw(bus_target_rw),
        .bus_target_ack(bus_target_ack)
    );

    always @(posedge clk) begin
        if (rst_n) begin
            if (bus_target_ack !== target_ack) begin
                $error("target_ack pass-through mismatch");
            end
            if (bus_target_ready !== target_ready) begin
                $error("target_ready pass-through mismatch");
            end
            if (bus_target_rw !== target_rw) begin
                $error("target_rw pass-through mismatch");
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ack_count <= 0;
            read_ack_count <= 0;
        end else begin
            if (bus_target_ack && bus_target_rw) begin
                write_ack_count <= write_ack_count + 1;
            end else if (bus_target_ack && !bus_target_rw) begin
                read_ack_count <= read_ack_count + 1;
            end
        end
    end

    task automatic drive_serial(input bit [15:0] value, input int width, input logic mode_bit);
        begin
            for (int i = 0; i < width; i++) begin
                bus_data_in <= value[i];
                bus_data_in_valid <= 1'b1;
                bus_mode <= mode_bit;
                @(posedge clk);
            end
            bus_data_in_valid <= 1'b0;
            bus_mode <= 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic issue_write(input bit [15:0] addr, input bit [7:0] data);
        begin
            target_rw <= 1'b1;
            @(posedge clk);
            drive_serial(addr, 16, 1'b0);
            drive_serial({8'h00, data}, 8, 1'b1);
        end
    endtask

    task automatic issue_read(input bit [15:0] addr);
        begin
            target_rw <= 1'b0;
            @(posedge clk);
            drive_serial(addr, 16, 1'b0);
        end
    endtask

    task automatic capture_read(output bit [7:0] data);
        int bit_idx;
        begin
            data = '0;
            bit_idx = 0;
            while (bit_idx < 8) begin
                @(posedge clk);
                if (bus_data_out_valid) begin
                    data[bit_idx] = bus_data_out;
                    bit_idx++;
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        bus_data_in = 1'b0;
        bus_data_in_valid = 1'b0;
        bus_mode = 1'b0;
        target_rw = 1'b0;
        read_back_serial = '0;
        decoder_valid = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        decoder_valid = 1'b1;
        issue_write(WRITE_ADDR, WRITE_DATA);
        wait (write_ack_count == 1);
        target_rw <= 1'b0;
        @(posedge clk);

        issue_read(READ_ADDR);
        capture_read(read_back_serial);
        wait (read_ack_count == 1);

        decoder_valid = 1'b0;

        if (read_back_serial !== WRITE_DATA) begin
            $error("Read data mismatch. Expected %h, got %h", WRITE_DATA, read_back_serial);
        end

        if (write_ack_count != 1) begin
            $error("Unexpected write ACK count %0d", write_ack_count);
        end

        if (read_ack_count != 1) begin
            $error("Unexpected read ACK count %0d", read_ack_count);
        end

        $display("[%0t] target integration test completed.", $time);
        $finish;
    end
endmodule
