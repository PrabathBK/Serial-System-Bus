module init_port(
    input logic clk,
    input logic rst_n,
    input logic init_req,
    input logic arbiter_grant,
    input logic [7:0] init_data_out,
    input logic init_data_out_valid,
    input logic [15:0] init_addr_out,
    input logic init_addr_out_valid,
    input logic init_rw, // 1 for write, 0 for read
    input logic init_ready,
    input logic target_split,
    input logic target_ack,
    input logic bus_data_in_valid,
    input logic bus_data_in,
    output logic bus_data_out,
    output logic init_grant,
    output logic [7:0] init_data_in,
    output logic init_data_in_valid,
    output logic bus_data_out_valid,
    output logic arbiter_req,
    output logic bus_mode, // 1 for data, 0 for address
    output logic init_ack,
    output logic bus_init_ready,
    output logic bus_init_rw,
    output logic init_split_ack
);

assign init_grant = arbiter_grant;
assign arbiter_req = init_req;
assign bus_init_rw = init_rw;
assign bus_init_ready = init_ready;
logic init_ack_reg;
logic ack_pending_read;
logic read_data_pending;
logic [7:0] read_data_buffer;

assign init_ack = init_ack_reg;
assign init_split_ack = target_split;

logic [15:0] tx_shift;
logic [4:0] tx_bits_remaining;
logic tx_active;
logic [7:0] rx_shift;
logic [2:0] rx_bit_count;
logic [15:0] pending_addr;
logic addr_pending;
logic [7:0] pending_data;
logic data_pending;
logic addr_is_read;
logic expect_read_data;
logic rx_byte_ready;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_shift <= '0;
        tx_bits_remaining <= '0;
        tx_active <= 1'b0;
        bus_data_out <= 1'b0;
        bus_data_out_valid <= 1'b0;
        pending_addr <= '0;
        addr_pending <= 1'b0;
        pending_data <= '0;
        data_pending <= 1'b0;
        addr_is_read <= 1'b0;
        expect_read_data <= 1'b0;
        bus_mode <= 1'b0;
    end else begin
        bus_data_out_valid <= 1'b0;

        if (rx_byte_ready)
            expect_read_data <= 1'b0;

        if (arbiter_grant && init_req) begin
            if (init_addr_out_valid) begin
                pending_addr <= init_addr_out;
                addr_pending <= 1'b1;
                addr_is_read <= (init_rw == 1'b0);
            end

            if (init_data_out_valid) begin
                pending_data <= init_data_out;
                data_pending <= 1'b1;
            end
        end

        if (tx_active) begin
            bus_data_out <= tx_shift[0];
            bus_data_out_valid <= 1'b1;
            tx_shift <= {1'b0, tx_shift[15:1]};

            if (tx_bits_remaining == 5'd1) begin
                tx_active <= 1'b0;
                tx_bits_remaining <= '0;
            end else begin
                tx_bits_remaining <= tx_bits_remaining - 5'd1;
            end
        end else begin
            if (addr_pending) begin
                tx_shift <= pending_addr;
                tx_bits_remaining <= 5'd16;
                tx_active <= 1'b1;
                bus_mode <= 1'b0;
                addr_pending <= 1'b0;
                expect_read_data <= addr_is_read;
            end else if (data_pending) begin
                tx_shift <= {8'd0, pending_data};
                tx_bits_remaining <= 5'd8;
                tx_active <= 1'b1;
                bus_mode <= 1'b1;
                data_pending <= 1'b0;
                expect_read_data <= 1'b0;
            end else begin
                bus_mode <= expect_read_data ? 1'b1 : 1'b0;
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    logic data_complete_now;

    if (!rst_n) begin
        rx_shift <= '0;
        rx_bit_count <= '0;
        init_data_in <= '0;
        init_data_in_valid <= 1'b0;
        rx_byte_ready <= 1'b0;
        init_ack_reg <= 1'b0;
        ack_pending_read <= 1'b0;
        read_data_pending <= 1'b0;
        read_data_buffer <= '0;
    end else begin
        logic data_now_valid;
        logic [7:0] data_now_value;
        logic release_data_now;
        logic [7:0] release_data_value;

        data_now_valid = 1'b0;
        data_now_value = '0;
        release_data_now = 1'b0;
        release_data_value = read_data_buffer;
        init_data_in_valid <= 1'b0;
        rx_byte_ready <= 1'b0;
        init_ack_reg <= 1'b0;

        // Only sample the shared bus when the initiator is not actively driving.
        if (bus_data_in_valid && !tx_active) begin
            logic [7:0] rx_next;
            rx_next = rx_shift;
            rx_next[rx_bit_count] = bus_data_in;

            if (rx_bit_count == 3'd7) begin
                rx_bit_count <= 3'd0;
                rx_shift <= '0;
                rx_byte_ready <= 1'b1;
                data_now_valid = 1'b1;
                data_now_value = rx_next;

                if (expect_read_data || ack_pending_read || read_data_pending) begin
                    read_data_buffer <= rx_next;
                    read_data_pending <= 1'b1;
                end else begin
                    init_data_in <= rx_next;
                    init_data_in_valid <= 1'b1;
                end
            end else begin
                rx_bit_count <= rx_bit_count + 3'd1;
                rx_shift <= rx_next;
            end
        end

        // Ack handling: pair read data with ACK when both are available.
        if (target_ack) begin
            if (data_now_valid || read_data_pending || ack_pending_read || expect_read_data) begin
                if (data_now_valid) begin
                    release_data_now = 1'b1;
                    release_data_value = data_now_value;
                    init_ack_reg <= 1'b1;
                    read_data_pending <= 1'b0;
                    ack_pending_read <= 1'b0;
                end else if (read_data_pending) begin
                    release_data_now = 1'b1;
                    release_data_value = read_data_buffer;
                    init_ack_reg <= 1'b1;
                    read_data_pending <= 1'b0;
                    ack_pending_read <= 1'b0;
                end else begin
                    ack_pending_read <= 1'b1;
                end
            end else begin
                init_ack_reg <= 1'b1;
            end
        end

        if (!target_ack && ack_pending_read && data_now_valid) begin
            release_data_now = 1'b1;
            release_data_value = data_now_value;
            init_ack_reg <= 1'b1;
            ack_pending_read <= 1'b0;
            read_data_pending <= 1'b0;
        end

        if (release_data_now) begin
            init_data_in <= release_data_value;
            init_data_in_valid <= 1'b1;
        end
    end
end

endmodule
