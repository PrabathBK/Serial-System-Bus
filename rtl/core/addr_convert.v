
module addr_convert #(
    parameter BB_ADDR_WIDTH = 12,
    parameter BUS_ADDR_WIDTH = 16,
    parameter BUS_MEM_ADDR_WIDTH = 12
) (
    input [BB_ADDR_WIDTH-1:0] bb_addr,
    output [BUS_ADDR_WIDTH-1:0] bus_addr
);
	//localparam BB_WIDTH = 13;

    assign bus_addr[(BUS_MEM_ADDR_WIDTH-1):0] = {{(BUS_MEM_ADDR_WIDTH-BB_ADDR_WIDTH+1){1'b0}}, bb_addr[(BB_ADDR_WIDTH-2):0]};
    assign bus_addr[BUS_MEM_ADDR_WIDTH] = bb_addr[BB_ADDR_WIDTH-1];
    assign bus_addr[BUS_ADDR_WIDTH-1:BUS_MEM_ADDR_WIDTH+1] = 'b0;
	 
	/*assign bus_addr[(BUS_MEM_ADDR_WIDTH-1):0] = {{(BUS_MEM_ADDR_WIDTH-BB_WIDTH+1){1'b0}}, bb_addr[(BB_WIDTH-2):0]};
    assign bus_addr[BUS_MEM_ADDR_WIDTH] = bb_addr[BB_WIDTH-1];
    assign bus_addr[BUS_ADDR_WIDTH-1:BUS_MEM_ADDR_WIDTH+1] = 'b0;*/

endmodule