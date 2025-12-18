module target #(
    parameter int INTERNAL_ADDR_BITS = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [15:0] target_addr_in,
    input  logic target_addr_in_valid,
    input  logic [7:0] target_data_in,
    input  logic target_data_in_valid,
    input  logic target_rw,
    output logic [7:0] target_data_out,
    output logic target_data_out_valid,
    output logic target_ack,
    output logic target_ready,
    output logic [7:0] target_last_write
);

    localparam int ADDR_WIDTH = (INTERNAL_ADDR_BITS > 0) ? INTERNAL_ADDR_BITS : 1;
    // localparam int MEM_DEPTH = 1 << ADDR_WIDTH;
    localparam int MEM_DEPTH = 16;

    // logic [7:0] mem [0:MEM_DEPTH-1];
    logic [7:0] mem [0:15];
    // logic [ADDR_WIDTH-1:0] pending_addr_idx;
    logic [3:0] pending_addr_idx;
    logic pending_write;

    logic [7:0] last_write_value;
    assign target_ready = 1'b1;

    assign target_last_write = last_write_value;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_data_out <= '0;
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            pending_addr_idx <= '0;
            pending_write <= 1'b0;
            last_write_value <= '0;
        end else begin
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;

            if (pending_write && target_data_in_valid) begin
                // mem[pending_addr_idx] <= target_data_in;
                mem[pending_addr_idx] <= target_data_in;
                target_ack <= 1'b1;
                pending_write <= 1'b0;
                last_write_value <= target_data_in;
            end

            if (target_addr_in_valid) begin
                // pending_addr_idx <= target_addr_in[ADDR_WIDTH-1:0];
                pending_addr_idx <= target_addr_in[3:0];

                if (target_rw) begin
                    if (target_data_in_valid) begin
                        // mem[target_addr_in[ADDR_WIDTH-1:0]] <= target_data_in;
                        mem[target_addr_in[3:0]] <= target_data_in;
                        target_ack <= 1'b1;
                        pending_write <= 1'b0;
                        last_write_value <= target_data_in;
                    end else begin
                        pending_write <= 1'b1;
                    end
                end else begin
                    // target_data_out <= mem[target_addr_in[ADDR_WIDTH-1:0]];
                    target_data_out <= mem[target_addr_in[3:0]];
                    target_data_out_valid <= 1'b1;
                    target_ack <= 1'b1;
                    pending_write <= 1'b0;
                end
            end
        end
    end
endmodule
