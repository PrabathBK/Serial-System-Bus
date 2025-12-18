import bus_bridge_pkg::*;

module bus_bridge_initiator_if(
    input  logic clk,
    input  logic rst_n,
    input  logic req_valid,
    output logic req_ready,
    input  bus_bridge_req_t req_payload,
    output logic resp_valid,
    input  logic resp_ready,
    output bus_bridge_resp_t resp_payload,
    output logic init_req,
    output logic [15:0] init_addr_out,
    output logic init_addr_out_valid,
    output logic [7:0] init_data_out,
    output logic init_data_out_valid,
    output logic init_rw,
    output logic init_ready,
    input  logic init_grant,
    input  logic [7:0] init_data_in,
    input  logic init_data_in_valid,
    input  logic init_ack,
    input  logic init_split_ack
);

    typedef enum logic [1:0] {
        BI_IDLE,
        BI_SEND,
        BI_WAIT_ACK,
        BI_RESP_HOLD
    } initiator_state_t;

    initiator_state_t state;
    bus_bridge_req_t active_req;
    bus_bridge_resp_t response_buffer;
    logic init_req_reg;
    logic init_addr_valid_reg;
    logic init_data_valid_reg;
    logic init_rw_reg;
    logic addr_captured;
    logic data_captured;
    logic [7:0] read_data_buffer;
    logic read_data_valid;
    logic resp_valid_reg;
    logic pending_read_ack;

    assign req_ready = (state == BI_IDLE);
    assign init_addr_out = active_req.addr;
    assign init_addr_out_valid = init_addr_valid_reg;
    assign init_data_out = active_req.write_data;
    assign init_data_out_valid = init_data_valid_reg;
    assign init_req = init_req_reg;
    assign init_rw = init_rw_reg;
    assign init_ready = 1'b1;
    assign resp_valid = resp_valid_reg;
    assign resp_payload = response_buffer;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= BI_IDLE;
            active_req <= '0;
            response_buffer <= '0;
            init_req_reg <= 1'b0;
            init_addr_valid_reg <= 1'b0;
            init_data_valid_reg <= 1'b0;
            init_rw_reg <= 1'b1;
            addr_captured <= 1'b0;
            data_captured <= 1'b0;
            read_data_buffer <= '0;
            read_data_valid <= 1'b0;
            resp_valid_reg <= 1'b0;
            pending_read_ack <= 1'b0;
        end else begin
            if (init_data_in_valid) begin
                read_data_buffer <= init_data_in;
                read_data_valid <= 1'b1;
            end

            case (state)
                BI_IDLE: begin
                    init_req_reg <= 1'b0;
                    init_addr_valid_reg <= 1'b0;
                    init_data_valid_reg <= 1'b0;
                    resp_valid_reg <= 1'b0;
                    read_data_valid <= 1'b0;
                    pending_read_ack <= 1'b0;
                    addr_captured <= 1'b0;
                    data_captured <= 1'b0;
                    if (req_valid) begin
                        active_req <= req_payload;
                        init_req_reg <= 1'b1;
                        init_rw_reg <= req_payload.is_write;
                        init_addr_valid_reg <= 1'b1;
                        init_data_valid_reg <= req_payload.is_write;
                        addr_captured <= 1'b0;
                        data_captured <= ~req_payload.is_write;
                        state <= BI_SEND;
                    end
                end

                BI_SEND: begin
                    if (!addr_captured && init_grant && init_addr_valid_reg) begin
                        addr_captured <= 1'b1;
                        init_addr_valid_reg <= 1'b0;
                    end

                    if (active_req.is_write && !data_captured && init_grant && init_data_valid_reg) begin
                        data_captured <= 1'b1;
                        init_data_valid_reg <= 1'b0;
                    end

                    if (addr_captured && data_captured) begin
                        state <= BI_WAIT_ACK;
                    end
                end

                BI_WAIT_ACK: begin
                    if (init_split_ack)
                        init_req_reg <= 1'b0;

                    if (init_ack) begin
                        init_req_reg <= 1'b0;
                        if (active_req.is_write || read_data_valid) begin
                            response_buffer.is_write <= active_req.is_write;
                            response_buffer.read_data <= active_req.is_write ? 8'h00 : read_data_buffer;
                            resp_valid_reg <= 1'b1;
                            pending_read_ack <= 1'b0;
                            if (!active_req.is_write)
                                read_data_valid <= 1'b0;
                            state <= BI_RESP_HOLD;
                        end else begin
                            pending_read_ack <= 1'b1;
                        end
                    end

                    if (!active_req.is_write && pending_read_ack && read_data_valid) begin
                        response_buffer.is_write <= 1'b0;
                        response_buffer.read_data <= read_data_buffer;
                        resp_valid_reg <= 1'b1;
                        pending_read_ack <= 1'b0;
                        read_data_valid <= 1'b0;
                        state <= BI_RESP_HOLD;
                    end
                end

                BI_RESP_HOLD: begin
                    if (resp_ready) begin
                        resp_valid_reg <= 1'b0;
                        state <= BI_IDLE;
                    end
                end

                default: state <= BI_IDLE;
            endcase
        end
    end
endmodule
