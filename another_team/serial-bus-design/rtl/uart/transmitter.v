module ot_transmitter #(parameter DATA_BITS = 8)(
							input wire [DATA_BITS-1:0] data_in,
							input wire wr_en,
							input wire clk_50m,
							input wire clken,
							output reg Tx,
							output wire Tx_busy
							);

initial 
	begin
		 Tx = 1'b1; //initialize Tx = 1 to begin the transmission 
	end
	
//Define the 4 states using 00,01,10,11 signals
parameter TX_STATE_IDLE	= 2'b00;
parameter TX_STATE_START	= 2'b01;
parameter TX_STATE_DATA	= 2'b10;
parameter TX_STATE_STOP	= 2'b11;

localparam BIT_INDEX_WIDTH = (DATA_BITS > 1) ? $clog2(DATA_BITS) : 1;

reg [DATA_BITS-1:0] data = {DATA_BITS{1'b0}};
reg [BIT_INDEX_WIDTH-1:0] bit_pos = {BIT_INDEX_WIDTH{1'b0}};
reg [1:0] state = TX_STATE_IDLE;  //state is a 2 bit register/vector,initially equal to 00

reg flag1 = 1'b0;
reg flag2 = 1'b1;

always @(posedge wr_en)
begin
	flag1 <= ~flag1;
end

always @(posedge clk_50m) 

begin
	case (state) //Let us consider the 4 states of the transmitter
	TX_STATE_IDLE: 
		begin //We define the conditions for idle  or NOT-BUSY state
			if (flag1 == flag2) 
			begin
				state <= TX_STATE_START; //assign the start signal to state
				data <= data_in; //we assign input data vector to the current data 
				bit_pos <= {BIT_INDEX_WIDTH{1'b0}}; //we assign the bit position to zero
				flag2 <= ~flag2;
			end
		end
		
	TX_STATE_START: 
		begin //We define the conditions for the transmission start state
			if (clken) 
			begin
				Tx <= 1'b0; //set Tx = 0 indicating transmission has started
				state <= TX_STATE_DATA;
			end
		end
		
	TX_STATE_DATA: 
		begin
			if (clken) 
			begin
				if (bit_pos == DATA_BITS - 1) //we keep assigning Tx with the data until all bits have been transmitted
					state <= TX_STATE_STOP; // when bit position has finally reached the last bit, assign state to stop transmission
				else
					bit_pos <= bit_pos + 1'b1; //increment the bit position by 1
				Tx <= data[bit_pos]; //Set Tx to the data value of the current bit position
			end
		end
		
	TX_STATE_STOP: 
		begin
			if (clken) 
			begin
				Tx <= 1'b1; //set Tx = 1 after transmission has ended
				state <= TX_STATE_IDLE; //Move to IDLE state once a transmission has been completed
			end
		end
		
	default: 
		begin
			Tx <= 1'b1; // always begin with Tx = 1 and state assigned to IDLE
			state <= TX_STATE_IDLE;
		end
	endcase
	
end

assign Tx_busy = (state != TX_STATE_IDLE); //We assign the BUSY signal when the transmitter is not idle

endmodule
