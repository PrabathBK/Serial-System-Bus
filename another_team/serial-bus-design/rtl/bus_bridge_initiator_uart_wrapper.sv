import bus_bridge_pkg::*;

module bus_bridge_initiator_uart_wrapper (
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rx,
    output logic uart_tx,
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

    bus_bridge_req_t req_payload_if;
    bus_bridge_resp_t resp_payload_if;
    logic req_valid_if;
    logic req_ready_if;
    logic resp_valid_if;
    logic resp_ready_if;

    bus_bridge_initiator_if u_initiator_if (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid_if),
        .req_ready(req_ready_if),
        .req_payload(req_payload_if),
        .resp_valid(resp_valid_if),
        .resp_ready(resp_ready_if),
        .resp_payload(resp_payload_if),
        .init_req(init_req),
        .init_addr_out(init_addr_out),
        .init_addr_out_valid(init_addr_out_valid),
        .init_data_out(init_data_out),
        .init_data_out_valid(init_data_out_valid),
        .init_rw(init_rw),
        .init_ready(init_ready),
        .init_grant(init_grant),
        .init_data_in(init_data_in),
        .init_data_in_valid(init_data_in_valid),
        .init_ack(init_ack),
        .init_split_ack(init_split_ack)
    );

    typedef enum logic [2:0] {
        REQ_RX_IDLE,
        REQ_RX_WAIT_ADDR_H,
        REQ_RX_WAIT_DATA,
        REQ_RX_WAIT_FLAGS,
        REQ_RX_HOLD
    } req_rx_state_t;

    req_rx_state_t req_rx_state;
    bus_bridge_req_t req_pending;
    logic req_valid_reg;

    logic uart_wr_en;
    logic [7:0] uart_data_in;
    logic uart_tx_busy;
    logic uart_ready;
    logic uart_ready_clr;
    logic [7:0] uart_data_out;
    logic uart_tx_busy_d;
    logic uart_ready_q;

    assign req_valid_if = req_valid_reg;
    assign req_payload_if = req_pending;

    ot_uart #(
        .DATA_BITS(8)
    ) u_initiator_uart (
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
            req_rx_state <= REQ_RX_IDLE;
            req_pending <= '0;
            req_valid_reg <= 1'b0;
            uart_ready_clr <= 1'b0;
        end else begin
            uart_ready_clr <= 1'b0;

            if (req_valid_reg && req_ready_if)
                req_valid_reg <= 1'b0;

            case (req_rx_state)
                REQ_RX_IDLE: begin
                    if (!req_valid_reg && uart_ready_pulse) begin
                        req_pending.addr[7:0] <= uart_data_out; // byte0: address LSB
                        uart_ready_clr <= 1'b1;
                        req_rx_state <= REQ_RX_WAIT_ADDR_H;
                    end
                end

                REQ_RX_WAIT_ADDR_H: begin
                    if (uart_ready_pulse) begin
                        req_pending.addr[15:8] <= uart_data_out; // byte1: address MSB
                        uart_ready_clr <= 1'b1;
                        req_rx_state <= REQ_RX_WAIT_DATA;
                    end
                end

                REQ_RX_WAIT_DATA: begin
                    if (uart_ready_pulse) begin
                        req_pending.write_data <= uart_data_out; // byte2: write data
                        uart_ready_clr <= 1'b1;
                        req_rx_state <= REQ_RX_WAIT_FLAGS;
                    end
                end

                REQ_RX_WAIT_FLAGS: begin
                    if (uart_ready_pulse) begin
                        req_pending.is_write <= uart_data_out[0]; // byte3 bit0: is_write
                        req_valid_reg <= 1'b1;
                        uart_ready_clr <= 1'b1;
                        req_rx_state <= REQ_RX_HOLD;
                    end
                end

                REQ_RX_HOLD: begin
                    if (!req_valid_reg)
                        req_rx_state <= REQ_RX_IDLE;
                end

                default: req_rx_state <= REQ_RX_IDLE;
            endcase
        end
    end

    typedef enum logic [2:0] {
        RESP_TX_IDLE,
        RESP_TX_SEND_DATA,
        RESP_TX_WAIT_DATA,
        RESP_TX_SEND_FLAGS,
        RESP_TX_WAIT_FLAGS
    } resp_tx_state_t;

    resp_tx_state_t resp_tx_state;
    bus_bridge_resp_t resp_pending;

    assign resp_ready_if = (resp_tx_state == RESP_TX_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_tx_state <= RESP_TX_IDLE;
            resp_pending <= '0;
            uart_wr_en <= 1'b0;
            uart_data_in <= 8'h00;
        end else begin
            uart_wr_en <= 1'b0;

            case (resp_tx_state)
                RESP_TX_IDLE: begin
                    if (resp_valid_if && resp_ready_if) begin
                        resp_pending <= resp_payload_if;
                        resp_tx_state <= RESP_TX_SEND_DATA;
                    end
                end

                RESP_TX_SEND_DATA: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= resp_pending.read_data; // byte0: read data
                        uart_wr_en <= 1'b1;
                        resp_tx_state <= RESP_TX_WAIT_DATA;
                    end
                end

                RESP_TX_WAIT_DATA: begin
                    if (uart_tx_done)
                        resp_tx_state <= RESP_TX_SEND_FLAGS;
                end

                RESP_TX_SEND_FLAGS: begin
                    if (!uart_tx_busy) begin
                        uart_data_in <= {7'b0, resp_pending.is_write}; // byte1: control flag
                        uart_wr_en <= 1'b1;
                        resp_tx_state <= RESP_TX_WAIT_FLAGS;
                    end
                end

                RESP_TX_WAIT_FLAGS: begin
                    if (uart_tx_done)
                        resp_tx_state <= RESP_TX_IDLE;
                end

                default: resp_tx_state <= RESP_TX_IDLE;
            endcase
        end
    end

endmodule
