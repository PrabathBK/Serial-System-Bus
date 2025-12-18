import bus_bridge_pkg::*;

module bus_bridge_target_uart_wrapper #(
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
    output logic uart_tx,
    input  logic uart_rx
);

    bus_bridge_req_t req_payload_if;
    bus_bridge_resp_t resp_payload_if;
    logic req_valid_if;
    logic req_ready_if;
    logic resp_valid_if;
    logic resp_ready_if;

    bus_bridge_target_if #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(TARGET0_SIZE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .BUSB_TARGET0_BASE(BUSB_TARGET0_BASE),
        .BUSB_TARGET1_BASE(BUSB_TARGET1_BASE),
        .BUSB_TARGET2_BASE(BUSB_TARGET2_BASE)
    ) u_target_if (
        .clk(clk),
        .rst_n(rst_n),
        .split_grant(split_grant),
        .target_addr_in(target_addr_in),
        .target_addr_in_valid(target_addr_in_valid),
        .target_data_in(target_data_in),
        .target_data_in_valid(target_data_in_valid),
        .target_rw(target_rw),
        .split_req(split_req),
        .target_data_out(target_data_out),
        .target_data_out_valid(target_data_out_valid),
        .target_ack(target_ack),
        .target_split_ack(target_split_ack),
        .target_ready(target_ready),
        .split_target_last_write(split_target_last_write),
        .req_valid(req_valid_if),
        .req_ready(req_ready_if),
        .req_payload(req_payload_if),
        .resp_valid(resp_valid_if),
        .resp_ready(resp_ready_if),
        .resp_payload(resp_payload_if)
    );

    typedef enum logic [3:0] {
        REQ_TX_IDLE,
        REQ_TX_SEND_ADDR_L,
        REQ_TX_WAIT_ADDR_L,
        REQ_TX_SEND_ADDR_H,
        REQ_TX_WAIT_ADDR_H,
        REQ_TX_SEND_DATA,
        REQ_TX_WAIT_DATA,
        REQ_TX_SEND_FLAGS,
        REQ_TX_WAIT_FLAGS
    } req_tx_state_t;

    req_tx_state_t req_tx_state;
    bus_bridge_req_t req_pending;
    logic uart_wr_en;
    logic [7:0] uart_data_in;
    logic uart_tx_busy;
    logic uart_ready;
    logic uart_ready_clr;
    logic [7:0] uart_data_out;
    logic uart_tx_busy_d;
    logic resp_valid_reg;
    bus_bridge_resp_t resp_pending;
    logic uart_ready_q;

    assign req_ready_if = (req_tx_state == REQ_TX_IDLE);
    assign resp_valid_if = resp_valid_reg;
    assign resp_payload_if = resp_pending;

    ot_uart #(
        .DATA_BITS(8)
    ) u_target_uart (
        .data_in(uart_data_in),
        .wr_en(uart_wr_en),
        .clear(1'b0),
        .clk_50m(clk),
        .Tx(uart_tx),
        .Tx_busy(uart_tx_busy),
        .Rx(uart_rx),
        .ready(uart_ready),
        .ready_clr(uart_ready_clr),
        .data_out(uart_data_out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uart_tx_busy_d <= 1'b0;
        else
            uart_tx_busy_d <= uart_tx_busy;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uart_ready_q <= 1'b0;
        else
            uart_ready_q <= uart_ready;
    end

    wire uart_ready_pulse = uart_ready && !uart_ready_q;

    wire uart_tx_done = uart_tx_busy_d && !uart_tx_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_tx_state <= REQ_TX_IDLE;
            req_pending <= '0;
            uart_wr_en <= 1'b0;
            uart_data_in <= 8'h00;
        end else begin
            uart_wr_en <= 1'b0;
            case (req_tx_state)
                REQ_TX_IDLE: begin
                    if (req_valid_if && req_ready_if) begin
                        req_pending <= req_payload_if;
                        req_tx_state <= REQ_TX_SEND_ADDR_L;
                    end
                end

                REQ_TX_SEND_ADDR_L: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= req_pending.addr[7:0]; // byte0: address LSB
                        uart_wr_en <= 1'b1;
                        req_tx_state <= REQ_TX_WAIT_ADDR_L;
                    end
                end

                REQ_TX_WAIT_ADDR_L: begin
                    if (uart_tx_done)
                        req_tx_state <= REQ_TX_SEND_ADDR_H;
                end

                REQ_TX_SEND_ADDR_H: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= req_pending.addr[15:8]; // byte1: address MSB
                        uart_wr_en <= 1'b1;
                        req_tx_state <= REQ_TX_WAIT_ADDR_H;
                    end
                end

                REQ_TX_WAIT_ADDR_H: begin
                    if (uart_tx_done)
                        req_tx_state <= REQ_TX_SEND_DATA;
                end

                REQ_TX_SEND_DATA: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= req_pending.write_data; // byte2: write data
                        uart_wr_en <= 1'b1;
                        req_tx_state <= REQ_TX_WAIT_DATA;
                    end
                end

                REQ_TX_WAIT_DATA: begin
                    if (uart_tx_done)
                        req_tx_state <= REQ_TX_SEND_FLAGS;
                end

                REQ_TX_SEND_FLAGS: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= {7'b0, req_pending.is_write}; // byte3: control flag
                        uart_wr_en <= 1'b1;
                        req_tx_state <= REQ_TX_WAIT_FLAGS;
                    end
                end

                default: begin
                    if (uart_tx_done)
                        req_tx_state <= REQ_TX_IDLE;
                end
            endcase
        end
    end

    typedef enum logic [1:0] {
        RESP_RX_IDLE,
        RESP_RX_WAIT_FLAGS,
        RESP_RX_HOLD
    } resp_rx_state_t;

    resp_rx_state_t resp_rx_state;
    logic [7:0] resp_read_byte;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_rx_state <= RESP_RX_IDLE;
            resp_read_byte <= 8'h00;
            resp_pending <= '0;
            resp_valid_reg <= 1'b0;
            uart_ready_clr <= 1'b0;
        end else begin
            uart_ready_clr <= 1'b0;

            if (resp_valid_reg && resp_ready_if)
                resp_valid_reg <= 1'b0;

            case (resp_rx_state)
                RESP_RX_IDLE: begin
                    if (uart_ready_pulse) begin
                        resp_read_byte <= uart_data_out;
                        uart_ready_clr <= 1'b1;
                        resp_rx_state <= RESP_RX_WAIT_FLAGS;
                    end
                end

                RESP_RX_WAIT_FLAGS: begin
                    if (uart_ready_pulse) begin
                        resp_pending.read_data <= resp_read_byte; // byte0 captured earlier
                        resp_pending.is_write <= uart_data_out[0]; // byte1 bit0
                        resp_valid_reg <= 1'b1;
                        uart_ready_clr <= 1'b1;
                        resp_rx_state <= RESP_RX_HOLD;
                    end
                end

                RESP_RX_HOLD: begin
                    if (!resp_valid_reg)
                        resp_rx_state <= RESP_RX_IDLE;
                end

                default: resp_rx_state <= RESP_RX_IDLE;
            endcase
        end
    end

endmodule
