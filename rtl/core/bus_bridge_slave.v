module bus_bridge_slave #(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 12,
    parameter UART_CLOCKS_PER_PULSE = 5208
)(
    input clk, rstn,
    // Signals connecting to serial bus
	input swdata,	// write data and address from master
	input smode,	// 0 -  read, 1 - write, from master
	input mvalid,	// wdata valid - (recieving data and address from master)
    input split_grant, // grant bus access in split
    
    output srdata,	// read data to the master
	output svalid,	// rdata valid - (sending data from slave)
    output sready, //slave is ready for transaction
    output ssplit,

    // Bus bridge UART signals
    output u_tx,
    input u_rx
);
    localparam UART_TX_DATA_WIDTH = DATA_WIDTH + ADDR_WIDTH + 1;    // Transmit all 3 info
    localparam UART_RX_DATA_WIDTH = DATA_WIDTH;     // Receive only read data
    localparam SPLIT_EN = 1'b0;
    
    // Slave port ready
    wire spready;

	// Signals connecting to slave port
	wire [DATA_WIDTH-1:0] smemrdata;
	wire smemwen;
    wire smemren; 
	wire [ADDR_WIDTH-1:0] smemaddr; 
	wire [DATA_WIDTH-1:0] smemwdata;
    wire rvalid;

    // Signals connecting to UART
    reg [UART_TX_DATA_WIDTH-1:0] u_din;
    reg u_en;
    wire u_tx_busy;
    wire u_rx_ready;
    wire [UART_RX_DATA_WIDTH-1:0] u_dout;

    // Signals connecting to FIFO (for buffering read responses from UART)
    reg fifo_enq;
    reg fifo_deq;
    reg [UART_RX_DATA_WIDTH-1:0] fifo_din;
    wire [UART_RX_DATA_WIDTH-1:0] fifo_dout;
    wire fifo_empty;

    reg prev_u_rx_ready;

    // Instantiate modules

    // Slave port
    slave_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SPLIT_EN(SPLIT_EN)
    )slave(
        .clk(clk), 
        .rstn(rstn),
        .smemrdata(smemrdata),
        .rvalid(rvalid),
        .smemwen(smemwen), 
        .smemren(smemren),
        .smemaddr(smemaddr), 
        .smemwdata(smemwdata),
        .swdata(swdata),
        .srdata(srdata),
        .smode(smode),
        .mvalid(mvalid),	
        .split_grant(split_grant),
        .svalid(svalid),	
        .sready(spready),
        .ssplit(ssplit)
    );


    // UART module
    uart #(
        .CLOCKS_PER_PULSE(UART_CLOCKS_PER_PULSE),
        .TX_DATA_WIDTH(UART_TX_DATA_WIDTH),
        .RX_DATA_WIDTH(UART_RX_DATA_WIDTH)
    ) uart_module (
        .data_input(u_din),
        .data_en(u_en),
        .clk(clk),
        .rstn(rstn),
        .tx(u_tx),  // Transmitter output (tx)
        .tx_busy(u_tx_busy),
        .rx(u_rx),  
        .ready(u_rx_ready),   
        .data_output(u_dout)
    );

    // FIFO module for buffering read responses from UART
    fifo #(
        .DATA_WIDTH(UART_RX_DATA_WIDTH),
        .DEPTH(8)
    ) fifo_queue (
        .clk(clk),
        .rstn(rstn),
        .enq(fifo_enq),
        .deq(fifo_deq),
        .data_in(fifo_din),
        .data_out(fifo_dout),
        .empty(fifo_empty)
    );

    localparam IDLE  = 2'b00,    //0
               WSEND  = 2'b01, 	// Write data
               RSEND = 2'b10,    // Read data
               RDATA = 2'b11;    // Wait until receive
	// State variables
	reg [1:0] state, next_state;

	// Next state logic
	always @(*) begin
		case (state)
			IDLE   : next_state = (smemwen) ? WSEND : ((smemren) ? RSEND : IDLE);
			WSEND  : next_state = (u_tx_busy) ? WSEND : IDLE;
            RSEND  : next_state = (u_tx_busy) ? RSEND : RDATA;
            // Stay in RDATA until FIFO has data, then transition to IDLE
            RDATA  : next_state = (!fifo_empty) ? IDLE : RDATA;
			default: next_state = IDLE;
		endcase
	end

	// State transition logic
	always @(posedge clk) begin
		state <= (!rstn) ? IDLE : next_state;
	end

    // Send UART received data to FIFO (same pattern as bus_bridge_master)
    always @(posedge clk) begin
        if (!rstn) begin
            fifo_din <= 'b0;
            fifo_enq <= 1'b0;
            prev_u_rx_ready <= 1'b0;
        end
        else begin
            prev_u_rx_ready <= u_rx_ready;

            if (u_rx_ready && !prev_u_rx_ready) begin
                fifo_din <= u_dout;
                fifo_enq <= 1'b1;
            end
            else begin
                fifo_din <= fifo_din;
                fifo_enq <= 1'b0;
            end
        end
    end

    // Dequeue from FIFO when we have data and are in RDATA state
    always @(posedge clk) begin
        if (!rstn) begin
            fifo_deq <= 1'b0;
        end
        else begin
            // Dequeue when FIFO has data and we're waiting for read response
            if (!fifo_empty && (state == RDATA)) begin
                fifo_deq <= 1'b1;
            end
            else begin
                fifo_deq <= 1'b0;
            end
        end
    end

    // Send write data from slave port to UART TX 
    always @(posedge clk) begin
        if (!rstn) begin
            u_din <= 'b0;
            u_en <= 1'b0;
        end
        else begin
            case (state) 
                IDLE : begin
                    u_din <= u_din;
                    u_en <= 1'b0;
                end

                WSEND : begin
                    // Send address , data, mode
                    u_din <= {1'b1, smemwdata, smemaddr}; //[0:11] ADDR  [12:19] WDATA [20] mode
                    u_en  <= 1'b1;
                end
                RSEND : begin
                    // Send read address, mode
                    u_din <= {1'b0, {DATA_WIDTH{1'b0}}, smemaddr}; //[0:11] ADDR  [12:19] WDATA [20] mode
                    u_en  <= 1'b1;                
                end
                RDATA : begin
                    // No transmission when not writing
                    u_din <= u_din;
                    u_en <= 1'b0;
                end

                default : begin
                    u_din <= u_din;
                    u_en <= 1'b0;
                end
            endcase
        end
    end

    // rvalid is asserted when FIFO has data during read operation
    assign rvalid = (state == RDATA) && (!fifo_empty);
    // Read data comes from FIFO output
    assign smemrdata = fifo_dout;
    assign sready = spready && !smemwen && !smemren && (state == IDLE);

endmodule