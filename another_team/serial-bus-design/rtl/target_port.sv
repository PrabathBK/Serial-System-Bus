module target_port(
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] target_data_out,
    input  logic target_data_out_valid,
    input  logic target_rw, // 1 for write, 0 for read
    input  logic target_ready,
    input  logic target_ack,
    input  logic decoder_valid,
    input  logic bus_data_in_valid,
    input  logic bus_data_in,
    input  logic bus_mode, // 1 for data, 0 for address
    output logic bus_data_out,
    output logic [7:0] target_data_in,
    output logic target_data_in_valid,
    output logic [15:0] target_addr_in,
    output logic target_addr_in_valid,
    output logic bus_data_out_valid,
    output logic bus_target_ready,
    output logic bus_target_rw,
    output logic bus_target_ack
);

    assign bus_target_rw = target_rw;
    assign bus_target_ready = target_ready;
    assign bus_target_ack = target_ack;

    logic [7:0] tx_shift;
    logic [3:0] tx_bits_remaining;
    logic tx_active;
    logic [15:0] rx_addr_shift;
    logic [4:0] addr_bit_count;
    logic [15:0] addr_buffer;
    logic addr_pending;
    logic addr_expect_data;
    logic [7:0] rx_data_shift;
    logic [2:0] data_bit_count;
    logic [7:0] data_buffer;
    logic data_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift <= '0;
            tx_bits_remaining <= '0;
            tx_active <= 1'b0;
            bus_data_out <= 1'b0;
            bus_data_out_valid <= 1'b0;
        end else begin
            bus_data_out_valid <= 1'b0;

            if (tx_active) begin
                bus_data_out <= tx_shift[0];
                bus_data_out_valid <= 1'b1;
                tx_shift <= {1'b0, tx_shift[7:1]};

                if (tx_bits_remaining == 4'd1) begin
                    tx_active <= 1'b0;
                    tx_bits_remaining <= '0;
                end else begin
                    tx_bits_remaining <= tx_bits_remaining - 4'd1;
                end
            end else if (target_data_out_valid) begin
                tx_shift <= target_data_out;
                tx_bits_remaining <= 4'd8;
                tx_active <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_addr_shift <= '0;
            addr_bit_count <= '0;
            addr_buffer <= '0;
            addr_pending <= 1'b0;
            addr_expect_data <= 1'b0;
            rx_data_shift <= '0;
            data_bit_count <= '0;
            data_buffer <= '0;
            data_pending <= 1'b0;
            target_addr_in <= '0;
            target_addr_in_valid <= 1'b0;
            target_data_in <= '0;
            target_data_in_valid <= 1'b0;
        end else begin
            target_addr_in_valid <= 1'b0;
            target_data_in_valid <= 1'b0;

            if (addr_pending && decoder_valid) begin
                if (!addr_expect_data) begin
                    target_addr_in <= addr_buffer;
                    target_data_in <= '0;
                    target_addr_in_valid <= 1'b1;
                    addr_pending <= 1'b0;
                    addr_expect_data <= 1'b0;
                end else if (data_pending) begin
                    target_addr_in <= addr_buffer;
                    target_data_in <= data_buffer;
                    target_addr_in_valid <= 1'b1;
                    target_data_in_valid <= 1'b1;
                    addr_pending <= 1'b0;
                    addr_expect_data <= 1'b0;
                    data_pending <= 1'b0;
                    data_buffer <= '0;
                end
            end

            if (addr_pending && !decoder_valid && !bus_data_in_valid && !bus_mode) begin
                addr_pending <= 1'b0;
                addr_expect_data <= 1'b0;
                data_pending <= 1'b0;
                data_buffer <= '0;
            end

            if (bus_data_in_valid && !tx_active) begin
                if (!bus_mode && !addr_pending) begin
                    logic [15:0] updated_addr;
                    updated_addr = rx_addr_shift;
                    updated_addr[addr_bit_count] = bus_data_in;

                    if (addr_bit_count == 5'd15) begin
                        addr_buffer <= updated_addr;
                        addr_pending <= 1'b1;
                        addr_expect_data <= target_rw;
                        rx_addr_shift <= '0;
                        addr_bit_count <= 5'd0;
                    end else begin
                        rx_addr_shift <= updated_addr;
                        addr_bit_count <= addr_bit_count + 5'd1;
                    end
                end else if (bus_mode && addr_pending && addr_expect_data && !data_pending) begin
                    logic [7:0] updated_data;
                    updated_data = rx_data_shift;
                    updated_data[data_bit_count] = bus_data_in;

                    if (data_bit_count == 3'd7) begin
                        data_buffer <= updated_data;
                        data_pending <= 1'b1;
                        rx_data_shift <= '0;
                        data_bit_count <= 3'd0;
                    end else begin
                        rx_data_shift <= updated_data;
                        data_bit_count <= data_bit_count + 3'd1;
                    end
                end
            end
        end
    end
endmodule
