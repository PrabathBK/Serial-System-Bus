module ot_uart #(
	parameter DATA_BITS = 8
)(
	input wire [DATA_BITS-1:0] data_in,
	input wire wr_en,
	input wire clear,
	input wire clk_50m,
	output wire Tx,
	output wire Tx_busy,
	input wire Rx,
	output wire ready,
	input wire ready_clr,
	output wire [DATA_BITS-1:0] data_out
);     

wire Txclk_en, Rxclk_en;

ot_baudrate uart_baud(
	.clk_50m(clk_50m),
	.Rxclk_en(Rxclk_en),
	.Txclk_en(Txclk_en)
);
							
ot_transmitter #(
	.DATA_BITS(DATA_BITS)
) uart_Tx(
	.data_in(data_in),
	.wr_en(wr_en),
	.clk_50m(clk_50m),
	.clken(Txclk_en), // Assign Tx clock to enable clock 
	.Tx(Tx),
	.Tx_busy(Tx_busy)
);
							
ot_receiver #(
	.DATA_BITS(DATA_BITS)
) uart_Rx(
	.Rx(Rx),
	.ready(ready),
	.ready_clr(ready_clr),
	.clk_50m(clk_50m),
	.clken(Rxclk_en), // Assign Rx clock to enable clock 
	.data(data_out)
);

endmodule
