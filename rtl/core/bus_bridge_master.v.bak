/*
    Data from UART should be sent as 
    {mode, data, addr}
*/

module bus_bridge_master #(
	parameter ADDR_WIDTH = 16, 
	parameter DATA_WIDTH = 8,
	parameter SLAVE_MEM_ADDR_WIDTH = 12,
    parameter BB_ADDR_WIDTH = 12,
    parameter UART_CLOCKS_PER_PULSE = 5208
)(
	input clk, rstn,
	
	// Signals connecting to serial bus
	input mrdata,	// read data
	output mwdata,	// write data and address
	output mmode,	// 0 -  read, 1 - write
	output mvalid,	// wdata valid
	input svalid,	// rdata valid

	// Signals to arbiter
	output mbreq,
	input mbgrant,
	input msplit,

	// Acknowledgement from address decoder 
	input ack,

    // Bus bridge UART signals
    output u_tx,
    input u_rx
);
    localparam UART_RX_DATA_WIDTH = DATA_WIDTH + BB_ADDR_WIDTH + 1;    // Receive all 3 info
    localparam UART_TX_DATA_WIDTH = DATA_WIDTH;     // Transmit only read data
    
	// Signals connecting to master port
	reg [DATA_WIDTH-1:0] dwdata; // write data
	wire [DATA_WIDTH-1:0] drdata;	// read data
	wire [ADDR_WIDTH-1:0] daddr;
	reg dvalid; 			 		// ready valid interface
	wire dready;
	reg dmode;					// 0 - read, 1 - write

    // Signals connecting to FIFO
    reg fifo_enq;
    reg fifo_deq;
    reg [UART_RX_DATA_WIDTH-1:0] fifo_din;
    wire [UART_RX_DATA_WIDTH-1:0] fifo_dout;
    wire fifo_empty;

    // Signals connecting to UART
    reg [UART_TX_DATA_WIDTH-1:0] u_din;
    reg u_en;
    wire u_tx_busy;
    wire u_rx_ready;
    wire [UART_RX_DATA_WIDTH-1:0] u_dout;

    reg [BB_ADDR_WIDTH-1:0] bb_addr;
    reg expect_rdata;
    reg prev_u_ready, prev_m_ready;

    // Instantiate modules

    // Master port
    master_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_MEM_ADDR_WIDTH(SLAVE_MEM_ADDR_WIDTH)
    ) master (
        .clk(clk),
        .rstn(rstn),
        .dwdata(dwdata),
        .drdata(drdata),
        .daddr(daddr),
        .dvalid(dvalid),
        .dready(dready),
        .dmode(dmode),
        .mrdata(mrdata),
        .mwdata(mwdata),
        .mmode(mmode),
        .mvalid(mvalid),
        .svalid(svalid),
        .mbreq(mbreq),
        .mbgrant(mbgrant),
        .msplit(msplit),
        .ack(ack)
    );

    // FIFO module
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

    // Address converter 
    addr_convert #(
        .BB_ADDR_WIDTH(BB_ADDR_WIDTH),
        .BUS_ADDR_WIDTH(ADDR_WIDTH),
        .BUS_MEM_ADDR_WIDTH(SLAVE_MEM_ADDR_WIDTH)
    ) addr_convert_module (
        .bb_addr(bb_addr),
        .bus_addr(daddr)
    );

    // Send UART received data to FIFO 
    always @(posedge clk) begin
        if (!rstn) begin
            fifo_din <= 'b0;
            fifo_enq <= 1'b0;
            prev_u_ready <= 1'b0;
        end
        else begin
            prev_u_ready <= u_rx_ready;

            if (u_rx_ready && !prev_u_ready) begin
                fifo_din <= u_dout;
                fifo_enq <= 1'b1;
            end
            else begin
                fifo_din <= fifo_din;
                fifo_enq <= 1'b0;
            end
        end
    end

    // Send FIFO data to master port 
    always @(posedge clk) begin
        if (!rstn) begin
            bb_addr <= 'b0;
            dwdata <= 'b0;
            dmode <= 1'b0;
            dvalid <= 1'b0;
            fifo_deq <= 1'b0;
            expect_rdata <= 1'b0;
        end
        else begin
            if (dready & !fifo_empty & !dvalid) begin
                bb_addr <= fifo_dout[BB_ADDR_WIDTH-1:0];
                dwdata <= fifo_dout[BB_ADDR_WIDTH+:DATA_WIDTH];
                dmode <= fifo_dout[BB_ADDR_WIDTH + DATA_WIDTH];
                dvalid <= 1'b1;
                fifo_deq <= 1'b1;
                expect_rdata <= !(fifo_dout[BB_ADDR_WIDTH + DATA_WIDTH]);
            end
            else begin
                bb_addr <= bb_addr;
                dwdata <= dwdata;
                dmode <= dmode;
                dvalid <= 1'b0;
                fifo_deq <= 1'b0;
                expect_rdata <= expect_rdata;
            end
        end
    end

    // Send bus read data to UART TX
    always @(posedge clk) begin
        if (!rstn) begin
            u_din <= 'b0;
            u_en <= 1'b0;
            prev_m_ready <= 1'b0;
        end
        else begin
            prev_m_ready <= dready;
            // Read request finished
            if (!prev_m_ready & dready & expect_rdata) begin
                u_din <= drdata;
                u_en <= 1'b1;
            end
            else begin
                u_din <= u_din;
                u_en <= 1'b0;
            end
        end
    end

endmodule