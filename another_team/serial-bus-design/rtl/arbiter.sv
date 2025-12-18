module ot_arbiter(
    input logic clk,
    input logic rst_n,
    input logic req_i_1,
    input logic req_i_2,
    input logic req_split,
    output logic grant_i_1,
    output logic grant_i_2,
    output logic grant_split,
    output logic [1:0] sel
);
    typedef enum logic [1:0] {
        IDLE,
        GRANT_1,
        GRANT_2,
        GRANT_SPLIT
    } state_t;

    state_t current_state, next_state;

    // State transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (req_split)
                    next_state = GRANT_SPLIT;
                else if (req_i_1)
                    next_state = GRANT_1;
                else if (req_i_2)
                    next_state = GRANT_2;
            end
            GRANT_1: begin
                if (!req_i_1)
                    next_state = IDLE;
            end
            GRANT_2: begin
                if (!req_i_2)
                    next_state = IDLE;
            end
            GRANT_SPLIT: begin
                if (!req_split)
                    next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always_comb begin
        grant_i_1 = 0;
        grant_i_2 = 0;
        grant_split = 0;
        sel = 2'b00;

        case (current_state)
            GRANT_1: begin
                grant_i_1 = 1;
                sel = 2'b01;
            end
            GRANT_2: begin
                grant_i_2 = 1;
                sel = 2'b10;
            end
            GRANT_SPLIT: begin
                grant_split = 1;
            end
        endcase
    end
endmodule
