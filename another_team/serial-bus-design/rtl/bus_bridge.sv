import bus_bridge_pkg::*;

module bus_bridge #(
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

    logic uart_req_serial;
    logic uart_resp_serial;

    bus_bridge_target_uart_wrapper #(
        .BRIDGE_BASE_ADDR(BRIDGE_BASE_ADDR),
        .TARGET0_SIZE(TARGET0_SIZE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .BUSB_TARGET0_BASE(BUSB_TARGET0_BASE),
        .BUSB_TARGET1_BASE(BUSB_TARGET1_BASE),
        .BUSB_TARGET2_BASE(BUSB_TARGET2_BASE)
    ) u_bridge_target (
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
        .uart_tx(uart_req_serial),
        .uart_rx(uart_resp_serial)
    );

    bus_bridge_initiator_uart_wrapper u_bridge_initiator (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_req_serial),
        .uart_tx(uart_resp_serial),
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

endmodule
