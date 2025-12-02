
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
) (
    input clk, rstn,
    input enq, deq,
    input [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output empty        // queue is empty (nothing to take out)
);

    reg [DATA_WIDTH-1:0] queue [0:DEPTH-1];

    reg [$clog2(DEPTH)-1:0] rp, wp;     // read pointer, write pointer
    wire full;                          // queue is full

    assign empty = (rp == wp);
    assign full = (rp == wp + 1);
    assign data_out = queue[rp];

   
    always @(posedge clk) begin
        if (!rstn) begin
            wp <= 'b0;
            rp <= 'b0;
        end
        else begin
            if (enq & !full) begin
                queue[wp] <= data_in;
                wp <= wp + 1;
            end 

            if (deq & !empty) begin
                rp <= rp + 1;
            end
        end
    end

endmodule