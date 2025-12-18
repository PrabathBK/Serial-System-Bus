module ot_addr_decoder #(
    parameter logic [15:0] TARGET1_BASE = 16'h0000,
    parameter int unsigned TARGET1_SIZE = 16'd2048,
    parameter logic [15:0] TARGET2_BASE = 16'h4000,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] TARGET3_BASE = 16'h8000,
    parameter int unsigned TARGET3_SIZE = 16'd4096
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        bus_data_in,
    input  logic        bus_data_in_valid,
    input  logic        bus_mode,          // 1 for data, 0 for address
    input  logic [2:0]  release_valids,    // one-hot release strobes from the bus
    output logic        target_1_valid,
    output logic        target_2_valid,
    output logic        target_3_valid,
    output logic [1:0]  sel
);

    localparam logic [15:0] TARGET1_LIMIT = TARGET1_BASE + 16'((TARGET1_SIZE > 0) ? (TARGET1_SIZE - 1) : 0);
    localparam logic [15:0] TARGET2_LIMIT = TARGET2_BASE + 16'((TARGET2_SIZE > 0) ? (TARGET2_SIZE - 1) : 0);
    localparam logic [15:0] TARGET3_LIMIT = TARGET3_BASE + 16'((TARGET3_SIZE > 0) ? (TARGET3_SIZE - 1) : 0);

    function automatic logic [2:0] decode_target(logic [15:0] addr);
        logic [2:0] result;
        result = 3'b000;

        if ((TARGET1_SIZE != 0) && (addr >= TARGET1_BASE) && (addr <= TARGET1_LIMIT))
            result[0] = 1'b1;
        if ((TARGET2_SIZE != 0) && (addr >= TARGET2_BASE) && (addr <= TARGET2_LIMIT))
            result[1] = 1'b1;
        if ((TARGET3_SIZE != 0) && (addr >= TARGET3_BASE) && (addr <= TARGET3_LIMIT))
            result[2] = 1'b1;

        return result;
    endfunction

    function automatic logic [1:0] encode_sel(logic [2:0] valid_vec);
        if (valid_vec[2])
            return 2'b10;
        else if (valid_vec[1])
            return 2'b01;
        else
            return 2'b00;
    endfunction

    logic [15:0] addr_shift;
    logic [4:0] addr_bit_count;
    logic hold_active;
    logic [2:0] held_valids;
    logic [1:0] held_sel;
    logic [2:0] pending_valids;
    logic [1:0] pending_sel;
    logic pending_load;

    assign sel = held_sel;
    assign target_1_valid = held_valids[0];
    assign target_2_valid = held_valids[1];
    assign target_3_valid = held_valids[2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_shift <= '0;
            addr_bit_count <= '0;
            hold_active <= 1'b0;
            held_valids <= 3'b000;
            held_sel <= 2'b00;
            pending_valids <= 3'b000;
            pending_sel <= 2'b00;
            pending_load <= 1'b0;
        end else begin
            logic [2:0] next_valids;
            logic [1:0] next_sel;
            logic       next_hold_active;

            next_valids = held_valids;
            next_sel = held_sel;
            next_hold_active = hold_active;

            if (pending_load) begin
                next_valids = pending_valids;
                next_sel = pending_sel;
                next_hold_active = |pending_valids;
                pending_load <= 1'b0;
            end

            if (|release_valids) begin
                next_valids &= ~release_valids;
                next_sel = encode_sel(next_valids);
                next_hold_active = |next_valids;
            end

            held_valids <= next_valids;
            held_sel <= next_sel;
            hold_active <= next_hold_active;

            if (!bus_mode && bus_data_in_valid && !hold_active) begin
                logic [15:0] addr_next;
                addr_next = {bus_data_in, addr_shift[15:1]};
                addr_shift <= addr_next;

                if (addr_bit_count == 5'd15) begin
                    logic [2:0] decoded_valids;
                    logic [1:0] decoded_sel;

                    decoded_valids = decode_target(addr_next);
                    decoded_sel = encode_sel(decoded_valids);

                    pending_valids <= decoded_valids;
                    pending_sel <= decoded_sel;
                    pending_load <= 1'b1;
                    addr_bit_count <= 5'd0;
                end else begin
                    addr_bit_count <= addr_bit_count + 5'd1;
                end
            end else if (!bus_mode && !bus_data_in_valid && !hold_active && !pending_load) begin
                addr_shift <= '0;
                addr_bit_count <= 5'd0;
            end
        end
    end

endmodule
