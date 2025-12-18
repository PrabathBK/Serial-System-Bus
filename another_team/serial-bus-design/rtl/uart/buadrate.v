//This is a baud rate generator to divide a 50MHz clock into a 115200 baud Tx/Rx pair.
//The Rx clock oversamples by 16x.
 
module ot_baudrate  (input wire clk_50m,
						output wire Rxclk_en,
						output wire Txclk_en
						);
						

//Want to interface to 115200 baud UART for Tx/Rx pair
//Hence, 50000000 / 115200 = 434 Clocks Per Bit.

parameter RX_ACC_MAX = 50000000 / (115200 * 16);      // = (1/115200) / (1/50000000)  / 16
parameter TX_ACC_MAX = 50000000 / 115200;
//parameter RX_ACC_MAX = 31;
//parameter TX_ACC_MAX = 511;
parameter RX_ACC_WIDTH = $clog2(RX_ACC_MAX);
parameter TX_ACC_WIDTH = $clog2(TX_ACC_MAX);
reg [RX_ACC_WIDTH - 1:0] rx_acc = 0;
reg [TX_ACC_WIDTH - 1:0] tx_acc = 0;


always @(posedge clk_50m) 
begin
	begin
		if (rx_acc == RX_ACC_MAX[RX_ACC_WIDTH - 1:0])
			rx_acc <= 0;
		else
			rx_acc <= rx_acc + 5'b1; //increment by 00001
	
		if (tx_acc == TX_ACC_MAX[TX_ACC_WIDTH - 1:0])
			tx_acc <= 0;
		else
			tx_acc <= tx_acc + 9'b1; //increment by 000000001
	end

//	begin
//		if (rx_acc == 5'b11111)
//			rx_acc <= 0;
//		else
//			rx_acc <= rx_acc + 5'b1; //increment by 00001
//	
//		if (tx_acc == 9'b111111111)
//			tx_acc <= 0;
//		else
//			tx_acc <= tx_acc + 9'b1; //increment by 000000001
//	end
	
//	rx_acc <= rx_acc + 5'b1; //increment by 00001
//	tx_acc <= tx_acc + 9'b1; //increment by 000000001
end

assign Rxclk_en = (rx_acc == 5'd0);
assign Txclk_en = (tx_acc == 9'd0);

//assign Rxclk_en = (rx_acc <= 5'b10000);
//assign Txclk_en = (tx_acc <= 9'b100000000);

endmodule
