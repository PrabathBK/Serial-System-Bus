module split_target #(
    parameter int INTERNAL_ADDR_BITS = 8,
    parameter int READ_LATENCY = 4
)(
    input  logic clk,
    input  logic rst_n,
    input  logic split_grant,
    input  logic [15:0] target_addr_in,
    input  logic target_addr_in_valid,
    input  logic [7:0] target_data_in,
    input  logic target_data_in_valid,
    input  logic target_rw,
    output logic split_req,
    output logic [7:0] target_data_out,
    output logic target_data_out_valid,
    output logic target_ack,
    output logic target_split_ack,
    output logic target_ready,
    output logic [7:0] split_target_last_write
);

    localparam int ADDR_WIDTH = (INTERNAL_ADDR_BITS > 0) ? INTERNAL_ADDR_BITS : 1;
    // localparam int MEM_DEPTH = 1 << ADDR_WIDTH;
    localparam int MEM_DEPTH = 16;
    localparam int LATENCY_WIDTH = (READ_LATENCY > 0) ? $clog2(READ_LATENCY + 1) : 1;

    // logic [7:0] mem [0:MEM_DEPTH-1];
    logic [7:0] mem [0:15];
    logic [15:0] pending_addr;
    // logic [ADDR_WIDTH-1:0] addr_index;
    logic [3:0] addr_index;
    logic [LATENCY_WIDTH-1:0] latency_cnt;
    logic [7:0] last_write_value;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_WAIT_WRITE_DATA,
        ST_READ_DEFER,
        ST_READ_REQUEST,
        ST_READ_SEND
    } state_t;

    state_t state;

    assign target_ready = 1'b1;
    assign split_target_last_write = last_write_value;
    // assign addr_index = pending_addr[ADDR_WIDTH-1:0];
    assign addr_index = pending_addr[3:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            split_req <= 1'b0;
            target_data_out <= '0;
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;
            last_write_value <= '0;
            pending_addr <= '0;
            latency_cnt <= '0;
            state <= ST_IDLE;
        end else begin
            split_req <= 1'b0;
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (target_addr_in_valid) begin
                        pending_addr <= target_addr_in;
                        if (target_rw) begin
                            if (target_data_in_valid) begin
                                // mem[target_addr_in[ADDR_WIDTH-1:0]] <= target_data_in;
                                mem[target_addr_in[3:0]] <= target_data_in;
                                target_ack <= 1'b1;
                                last_write_value <= target_data_in;
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_WRITE_DATA;
                            end
                        end else begin
                            if (READ_LATENCY > 0) begin
                                target_split_ack <= 1'b1;
                                latency_cnt <= (READ_LATENCY > 0) ? READ_LATENCY - 1 : '0;
                                state <= ST_READ_DEFER;
                            end else begin
                                state <= ST_READ_REQUEST;
                            end
                        end
                    end
                end

                ST_WAIT_WRITE_DATA: begin
                    if (target_data_in_valid) begin
                        // mem[pending_addr[ADDR_WIDTH-1:0]] <= target_data_in;
                        mem[pending_addr[3:0]] <= target_data_in;
                        target_ack <= 1'b1;
                        last_write_value <= target_data_in;
                        state <= ST_IDLE;
                    end
                end

                ST_READ_DEFER: begin
                    if (latency_cnt == '0) begin
                        state <= ST_READ_REQUEST;
                    end else begin
                        latency_cnt <= latency_cnt - 1'b1;
                    end
                end

                ST_READ_REQUEST: begin
                    split_req <= 1'b1;
                    if (split_grant) begin
                        split_req <= 1'b0;
                        state <= ST_READ_SEND;
                    end
                end

                ST_READ_SEND: begin
                    target_data_out <= mem[addr_index];
                    target_data_out_valid <= 1'b1;
                    target_ack <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
