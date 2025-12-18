module initiator #(
    parameter logic [15:0] WRITE_ADDR = 16'h0012,
    parameter logic [15:0] READ_ADDR = 16'h0034,
    parameter logic [7:0] MEM_INIT_DATA = 8'hAA
)(
    input  logic clk,
    input  logic rst_n,
    input  logic trigger,
    input  logic init_grant,
    input  logic init_ack,
    input  logic init_split_ack,
    input  logic [7:0] init_data_in,
    input  logic init_data_in_valid,
    output logic init_req,
    output logic [15:0] init_addr_out,
    output logic init_addr_out_valid,
    output logic [7:0] init_data_out,
    output logic init_data_out_valid,
    output logic init_rw,
    output logic init_ready,
    output logic done,
    output logic [7:0] read_data_value
);

assign init_ready = 1'b1;

logic init_req_r;
logic [15:0] init_addr_out_r;
logic init_addr_out_valid_r;
logic [7:0] init_data_out_r;
logic init_data_out_valid_r;
logic init_rw_r;
logic done_r;
// logic [7:0] write_mem;
logic [7:0] write_mem [0:3];
logic [1:0] write_ptr;
logic [7:0] read_mem;
logic addr_sent;
logic data_sent;
logic split_active;
logic split_resume_ack;

typedef enum logic [2:0] {
    S_IDLE,
    S_WRITE_REQ,
    S_WRITE_HOLD,
    S_WRITE_WAIT_ACK,
    S_READ_REQ,
    S_READ_WAIT,
    S_DONE
} state_t;

state_t state;

assign init_req = init_req_r;
assign init_addr_out = init_addr_out_r;
assign init_addr_out_valid = init_addr_out_valid_r;
assign init_data_out = init_data_out_r;
assign init_data_out_valid = init_data_out_valid_r;
assign init_rw = init_rw_r;
assign done = done_r;
assign read_data_value = read_mem;

initial begin
    for (int i = 0; i < 4; i++) begin
        write_mem[i] <= MEM_INIT_DATA + i[7:0];
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        init_req_r <= 1'b0;
        init_addr_out_r <= '0;
        init_addr_out_valid_r <= 1'b0;
        init_data_out_r <= '0;
        init_data_out_valid_r <= 1'b0;
        init_rw_r <= 1'b1;
        write_ptr <= 2'd0;
        read_mem <= 8'h00;
        addr_sent <= 1'b0;
        data_sent <= 1'b0;
        done_r <= 1'b0;
        split_active <= 1'b0;
        split_resume_ack <= 1'b0;
    end else begin
        case (state)
            S_IDLE: begin
                init_req_r <= 1'b0;
                init_addr_out_valid_r <= 1'b0;
                init_data_out_valid_r <= 1'b0;
                init_rw_r <= 1'b1;
                addr_sent <= 1'b0;
                data_sent <= 1'b0;
                done_r <= 1'b0;
                split_active <= 1'b0;
                split_resume_ack <= 1'b0;

                if (trigger)
                    state <= S_WRITE_REQ;
            end
            S_WRITE_REQ: begin
                logic addr_done;
                logic data_done;

                init_req_r <= 1'b1;
                init_rw_r <= 1'b1;

                if (!addr_sent) begin
                    init_addr_out_r <= WRITE_ADDR;
                    init_addr_out_valid_r <= 1'b1;
                end else begin
                    init_addr_out_valid_r <= 1'b0;
                end

                if (!data_sent) begin
                    // init_data_out_r <= write_mem;
                    init_data_out_r <= write_mem[write_ptr];
                    init_data_out_valid_r <= 1'b1;
                end else begin
                    init_data_out_valid_r <= 1'b0;
                end

                addr_done = addr_sent || (init_grant && init_addr_out_valid_r);
                data_done = data_sent || (init_grant && init_data_out_valid_r);

                addr_sent <= addr_done;
                data_sent <= data_done;

                if (addr_done && data_done)
                    state <= S_WRITE_HOLD;
            end
            S_WRITE_HOLD: begin
                init_req_r <= 1'b1;
                init_addr_out_valid_r <= 1'b0;
                init_data_out_valid_r <= 1'b0;

                if (init_ack) begin
                    init_req_r <= 1'b0;
                    addr_sent <= 1'b0;
                    data_sent <= 1'b0;
                    init_rw_r <= 1'b0;
                    state <= S_READ_REQ;
                end else if (!init_grant) begin
                    state <= S_WRITE_WAIT_ACK;
                end
            end
            S_WRITE_WAIT_ACK: begin
                init_req_r <= 1'b1;
                init_addr_out_valid_r <= 1'b0;
                init_data_out_valid_r <= 1'b0;
                addr_sent <= 1'b0;
                data_sent <= 1'b0;

                if (init_ack) begin
                    init_req_r <= 1'b0;
                    init_rw_r <= 1'b0;
                    state <= S_READ_REQ;
                end
            end
            S_READ_REQ: begin
                logic addr_done;

                init_req_r <= 1'b1;
                init_rw_r <= 1'b0;
                split_active <= 1'b0;
                split_resume_ack <= 1'b0;

                if (!addr_sent) begin
                    init_addr_out_r <= READ_ADDR;
                    init_addr_out_valid_r <= 1'b1;
                end else begin
                    init_addr_out_valid_r <= 1'b0;
                end

                init_data_out_valid_r <= 1'b0;

                addr_done = addr_sent || (init_grant && init_addr_out_valid_r);
                addr_sent <= addr_done;

                if (addr_done) begin
                    state <= S_READ_WAIT;
                end
            end
            S_READ_WAIT: begin
                init_addr_out_valid_r <= 1'b0;
                init_data_out_valid_r <= 1'b0;
                addr_sent <= 1'b0;
                data_sent <= 1'b0;

                if (init_split_ack) begin
                    split_active <= 1'b1;
                    init_req_r <= 1'b0;
                end

                if (init_ack) begin
                    init_req_r <= 1'b0;
                    if (split_active)
                        split_resume_ack <= 1'b1;
                end

                if (init_data_in_valid && (!split_active || init_ack || split_resume_ack)) begin
                    read_mem <= init_data_in;
                    if (write_ptr == 2'd3)
                        write_ptr <= 2'd0;
                    else
                        write_ptr <= write_ptr + 2'd1;
                    done_r <= 1'b1;
                    split_active <= 1'b0;
                    split_resume_ack <= 1'b0;
                    state <= S_DONE;
                end
            end
            S_DONE: begin
                init_req_r <= 1'b0;
                init_addr_out_valid_r <= 1'b0;
                init_data_out_valid_r <= 1'b0;
                init_rw_r <= 1'b0;
                done_r <= 1'b1;
                if (!trigger) begin
                    done_r <= 1'b0;
                    state <= S_IDLE;
                end
            end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule
