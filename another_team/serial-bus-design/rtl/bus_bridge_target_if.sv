import bus_bridge_pkg::*;

module bus_bridge_target_if #(
    parameter logic [15:0] BRIDGE_BASE_ADDR = 16'h8000,
    parameter int unsigned TARGET0_SIZE = 16'd2048,
    parameter int unsigned TARGET1_SIZE = 16'd4096,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] BUSB_TARGET0_BASE = 16'h0000,
    parameter logic [15:0] BUSB_TARGET1_BASE = 16'h4000,
    parameter logic [15:0] BUSB_TARGET2_BASE = 16'h8000
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
    output logic [7:0] split_target_last_write,
    output logic req_valid,
    input  logic req_ready,
    output bus_bridge_req_t req_payload,
    input  logic resp_valid,
    output logic resp_ready,
    input  bus_bridge_resp_t resp_payload
);

    localparam int unsigned TOTAL_SPAN = TARGET0_SIZE + TARGET1_SIZE + TARGET2_SIZE;

    typedef enum logic [2:0] {
        TGT_IDLE,
        TGT_WAIT_WRITE_DATA,
        TGT_SEND_REQ,
        TGT_WAIT_RESPONSE,
        TGT_WAIT_READ_GRANT
    } target_state_t;

    target_state_t state;
    logic [15:0] current_addr_b;
    logic [7:0] current_write_data;
    logic current_is_write;
    logic current_uses_split_path;
    logic [7:0] pending_read_data;
    logic [7:0] inflight_write_data;
    bus_bridge_req_t request_buffer;

    function automatic logic [15:0] map_to_bus_b(
        input logic [15:0] addr,
        output logic valid
    );
        int unsigned offset;
        logic [15:0] mapped;

        valid = 1'b0;
        mapped = 16'd0;
        if (addr < BRIDGE_BASE_ADDR)
            return mapped;

        offset = int'(addr) - int'(BRIDGE_BASE_ADDR);
        if (offset >= TOTAL_SPAN)
            return mapped;

        if (offset < TARGET0_SIZE) begin
            valid = 1'b1;
            mapped = BUSB_TARGET0_BASE + 16'(offset);
        end else if (offset < (TARGET0_SIZE + TARGET1_SIZE)) begin
            valid = 1'b1;
            mapped = BUSB_TARGET1_BASE + 16'(offset - TARGET0_SIZE);
        end else begin
            valid = 1'b1;
            mapped = BUSB_TARGET2_BASE + 16'(offset - TARGET0_SIZE - TARGET1_SIZE);
        end

        return mapped;
    endfunction

    assign target_ready = 1'b1;
    assign req_payload = request_buffer;
    assign resp_ready = (state == TGT_WAIT_RESPONSE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TGT_IDLE;
            req_valid <= 1'b0;
            split_req <= 1'b0;
            target_data_out <= '0;
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;
            split_target_last_write <= '0;
            current_addr_b <= '0;
            current_write_data <= '0;
            current_is_write <= 1'b0;
            current_uses_split_path <= 1'b0;
            pending_read_data <= '0;
            inflight_write_data <= '0;
            request_buffer <= '0;
        end else begin
            target_data_out_valid <= 1'b0;
            target_ack <= 1'b0;
            target_split_ack <= 1'b0;

            case (state)
                TGT_IDLE: begin
                    split_req <= 1'b0;
                    if (target_addr_in_valid) begin
                        logic mapped_valid;
                        logic [15:0] mapped_addr;
                        int unsigned offset;
                        logic uses_split_now;

                        mapped_addr = map_to_bus_b(target_addr_in, mapped_valid);
                        current_addr_b <= mapped_addr;
                        current_is_write <= target_rw;
                        current_write_data <= target_data_in;
                        offset = 0;
                        if (mapped_valid && (target_addr_in >= BRIDGE_BASE_ADDR))
                            offset = int'(target_addr_in) - int'(BRIDGE_BASE_ADDR);
                        uses_split_now = mapped_valid && (offset < TARGET0_SIZE);
                        current_uses_split_path <= uses_split_now;

                        target_split_ack <= 1'b1;

                        if (!mapped_valid) begin
                            target_ack <= 1'b1;
                            target_data_out <= 8'h00;
                            target_data_out_valid <= (target_rw == 1'b0);
                            state <= TGT_IDLE;
                        end else if (target_rw && !target_data_in_valid) begin
                            state <= TGT_WAIT_WRITE_DATA;
                        end else begin
                            state <= TGT_SEND_REQ;
                        end
                    end
                end

                TGT_WAIT_WRITE_DATA: begin
                    if (target_data_in_valid) begin
                        current_write_data <= target_data_in;
                        state <= TGT_SEND_REQ;
                    end
                end

                TGT_SEND_REQ: begin
                    request_buffer.is_write <= current_is_write;
                    request_buffer.addr <= current_addr_b;
                    request_buffer.write_data <= current_write_data;
                    req_valid <= 1'b1;

                    if (req_valid && req_ready) begin
                        req_valid <= 1'b0;
                        inflight_write_data <= current_write_data;
                        state <= TGT_WAIT_RESPONSE;
                    end
                end

                TGT_WAIT_RESPONSE: begin
                    split_req <= 1'b0;
                    if (resp_valid && resp_ready) begin
                        if (resp_payload.is_write) begin
                            target_ack <= 1'b1;
                            split_target_last_write <= inflight_write_data;
                            state <= TGT_IDLE;
                        end else if (current_uses_split_path) begin
                            pending_read_data <= resp_payload.read_data;
                            split_req <= 1'b1;
                            state <= TGT_WAIT_READ_GRANT;
                        end else begin
                            target_data_out <= resp_payload.read_data;
                            target_data_out_valid <= 1'b1;
                            target_ack <= 1'b1;
                            split_req <= 1'b0;
                            state <= TGT_IDLE;
                        end
                    end
                end

                TGT_WAIT_READ_GRANT: begin
                    split_req <= 1'b1;
                    if (split_grant) begin
                        split_req <= 1'b0;
                        target_data_out <= pending_read_data;
                        target_data_out_valid <= 1'b1;
                        target_ack <= 1'b1;
                        state <= TGT_IDLE;
                    end
                end

                default: state <= TGT_IDLE;
            endcase

        end
    end
endmodule
