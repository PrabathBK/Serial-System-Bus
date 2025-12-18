module ot_receiver  #(parameter DATA_BITS = 8)(
					input wire Rx,
					output reg ready,
					input wire ready_clr,
					input wire clk_50m,		
					input wire clken,
					output reg [DATA_BITS-1:0] data
					);
initial 
begin
	ready = 1'b0; // initialize ready = 0
	data = {DATA_BITS{1'b0}}; // initialize data vector
end

// Define the 3 states using 00,01,10 signals
parameter RX_STATE_START		= 2'b00;
parameter RX_STATE_DATA			= 2'b01;
parameter RX_STATE_STOP			= 2'b10;
parameter RX_STATE_READY_CLEAR 	= 2'b11;

localparam BIT_INDEX_WIDTH = (DATA_BITS > 1) ? $clog2(DATA_BITS) : 1;
localparam BIT_COUNT_WIDTH = BIT_INDEX_WIDTH + 1;

reg [1:0] state = RX_STATE_START; // state is a 2-bit register/vector,initially equal to 00
reg [3:0] sample = 0; // This is a 4-bit register  
reg [BIT_COUNT_WIDTH-1:0] bit_count = {BIT_COUNT_WIDTH{1'b0}}; // counts number of bits sampled
reg [DATA_BITS-1:0] scratch = {DATA_BITS{1'b0}}; // collected data bits

always @(posedge clk_50m) 
begin
	if (ready_clr)
		ready <= 1'b0; // This resets ready to 0

	if (clken) 
	begin
		case (state)          // Let us consider the 3 states of the receiver 
		
		
		RX_STATE_START:       // We define condtions for starting the receiver 
		begin 
			if (!Rx || sample != 0) // start counting from the first low sample
				sample <= sample + 4'b1; // increment by 0001
				
			if (sample == 15)           // once a full bit has been sampled
			begin 
				state <= RX_STATE_DATA; //	start collecting data bits
				bit_count <= {BIT_COUNT_WIDTH{1'b0}};
				sample <= 0; 
				scratch <= {DATA_BITS{1'b0}};
			end
		end
		
		
		
		RX_STATE_DATA:      // We define conditions for starting the data colleting
		begin 
			sample <= sample + 4'b1;  // increment by 0001
			if (sample == 4'h8) begin // we keep assigning Rx data until all bits have been captured
				scratch[bit_count[BIT_INDEX_WIDTH-1:0]] <= Rx;
				bit_count <= bit_count + 1'b1;
			end
			if (bit_count == DATA_BITS && sample == 15) // when the configured number of bits has been sampled
				state <= RX_STATE_STOP; // move to stop bit handling once the payload is complete
		end
		
		
		
		RX_STATE_STOP: 
		begin
			/*
			 * Our baud clock may not be running at exactly the
			 * same rate as the transmitter.  If we think that
			 * we're at least half way into the stop bit, allow
			 * transition into handling the next start bit.
			 */
			if (sample == 15 || (sample >= 8 && !Rx)) 
			begin
				state <= RX_STATE_READY_CLEAR;
				data <= scratch;
				ready <= 1'b1;
				sample <= 0;
				bit_count <= {BIT_COUNT_WIDTH{1'b0}};
			end 
			else begin
				sample <= sample + 4'b1;
			end
		end
		
		RX_STATE_READY_CLEAR:
		begin
			state <= RX_STATE_START;
			ready <= 1'b0;
		end
		
		default: 
		begin
			state <= RX_STATE_START; // always begin with state assigned to START
		end
		
		endcase
	end
end

endmodule
