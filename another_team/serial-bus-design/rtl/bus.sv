module bus #(
    parameter logic [15:0] TARGET1_BASE = 16'h0000,
    parameter int unsigned TARGET1_SIZE = 16'd2048,
    parameter logic [15:0] TARGET2_BASE = 16'h4000,
    parameter int unsigned TARGET2_SIZE = 16'd4096,
    parameter logic [15:0] TARGET3_BASE = 16'h8000,
    parameter int unsigned TARGET3_SIZE = 16'd4096
)(
    input  logic         clk,
    input  logic         rst_n,

    // Initiator 1 interface
    input  logic         init1_req,
    input  logic [7:0]   init1_data_out,
    input  logic         init1_data_out_valid,
    input  logic [15:0]  init1_addr_out,
    input  logic         init1_addr_out_valid,
    input  logic         init1_rw,
    input  logic         init1_ready,
    output logic         init1_grant,
    output logic [7:0]   init1_data_in,
    output logic         init1_data_in_valid,
    output logic         init1_ack,
    output logic         init1_split_ack,

    // Initiator 2 interface
    input  logic         init2_req,
    input  logic [7:0]   init2_data_out,
    input  logic         init2_data_out_valid,
    input  logic [15:0]  init2_addr_out,
    input  logic         init2_addr_out_valid,
    input  logic         init2_rw,
    input  logic         init2_ready,
    output logic         init2_grant,
    output logic [7:0]   init2_data_in,
    output logic         init2_data_in_valid,
    output logic         init2_ack,
    output logic         init2_split_ack,

    // Target 1 interface
    input  logic         target1_ready,
    input  logic         target1_ack,
    input  logic [7:0]   target1_data_out,
    input  logic         target1_data_out_valid,
    output logic [15:0]  target1_addr_in,
    output logic         target1_addr_in_valid,
    output logic [7:0]   target1_data_in,
    output logic         target1_data_in_valid,
    output logic         target1_rw,

    // Target 2 interface
    input  logic         target2_ready,
    input  logic         target2_ack,
    input  logic [7:0]   target2_data_out,
    input  logic         target2_data_out_valid,
    output logic [15:0]  target2_addr_in,
    output logic         target2_addr_in_valid,
    output logic [7:0]   target2_data_in,
    output logic         target2_data_in_valid,
    output logic         target2_rw,

    // Split target (target 3) interface
    input  logic         split_target_ready,
    input  logic         split_target_ack,
    input  logic         split_target_split_ack,
    input  logic [7:0]   split_target_data_out,
    input  logic         split_target_data_out_valid,
    input  logic         split_target_req,
    output logic [15:0]  split_target_addr_in,
    output logic         split_target_addr_in_valid,
    output logic [7:0]   split_target_data_in,
    output logic         split_target_data_in_valid,
    output logic         split_target_rw,
    output logic         split_target_grant
);

    typedef enum logic [1:0] {
        INIT_NONE = 2'b00,
        INIT_1    = 2'b01,
        INIT_2    = 2'b10
    } init_sel_t;

    // Initiator port wiring
    logic init1_bus_data_out;
    logic init1_bus_data_out_valid;
    logic init1_bus_mode;
    logic init1_bus_data_in;
    logic init1_bus_data_in_valid;
    logic init1_bus_init_ready;
    logic init1_bus_init_rw;
    logic init1_target_ack_int;
    logic init1_target_split_int;
    logic init1_arbiter_req;
    logic init1_arbiter_grant;

    logic init2_bus_data_out;
    logic init2_bus_data_out_valid;
    logic init2_bus_mode;
    logic init2_bus_data_in;
    logic init2_bus_data_in_valid;
    logic init2_bus_init_ready;
    logic init2_bus_init_rw;
    logic init2_target_ack_int;
    logic init2_target_split_int;
    logic init2_arbiter_req;
    logic init2_arbiter_grant;

    // Target port wiring
    logic target1_bus_data_out;
    logic target1_bus_data_out_valid;
    logic target1_bus_target_ack;

    logic target2_bus_data_out;
    logic target2_bus_data_out_valid;
    logic target2_bus_target_ack;

    logic split_port_bus_data_out;
    logic split_port_bus_data_out_valid;
    logic split_port_bus_target_ack;
    logic split_port_bus_split_ack;
    logic split_port_arbiter_split_req;

    logic [1:0] arb_sel_bits;
    init_sel_t active_init;
    logic [1:0] decoder_sel;
    logic       target1_valid;
    logic       target2_valid;
    logic       target3_valid;
    logic       target1_select_hold;
    logic       target2_select_hold;
    logic       target3_select_hold;
    logic       target1_release_pending;
    logic       target2_release_pending;
    logic       target3_release_pending;
    logic       target1_decoder_release;
    logic       target2_decoder_release;
    logic       target3_decoder_release;
    logic [2:0] decoder_release;
    logic [1:0] response_sel;
    logic       split_route_active;
    logic       split_response_pending;
    init_sel_t  target1_owner;
    init_sel_t  target2_owner;
    init_sel_t  target3_owner;
    init_sel_t  response_owner;
        init_sel_t target1_owner_eff;
        init_sel_t target2_owner_eff;
        init_sel_t target3_owner_eff;
    logic       target1_expect_data;
    logic       target1_data_seen;
    logic       target2_expect_data;
    logic       target2_data_seen;
    logic       target3_expect_data;
    logic       target3_data_seen;

    logic forward_data;
    logic forward_valid;
    logic forward_mode;

    logic last_bus_rw;
    logic current_bus_rw;

    init_sel_t split_owner;
    logic      grant_i1;
    logic      grant_i2;
    logic      grant_split;

    logic response_data;
    logic response_valid;
    logic response_ack;

    // Initiator ports
    init_port u_init_port_1 (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init1_req),
        .arbiter_grant(init1_arbiter_grant),
        .init_data_out(init1_data_out),
        .init_data_out_valid(init1_data_out_valid),
        .init_addr_out(init1_addr_out),
        .init_addr_out_valid(init1_addr_out_valid),
        .init_rw(init1_rw),
        .init_ready(init1_ready),
        .target_split(init1_target_split_int),
        .target_ack(init1_target_ack_int),
        .bus_data_in_valid(init1_bus_data_in_valid),
        .bus_data_in(init1_bus_data_in),
        .bus_data_out(init1_bus_data_out),
        .init_grant(init1_grant),
        .init_data_in(init1_data_in),
        .init_data_in_valid(init1_data_in_valid),
        .bus_data_out_valid(init1_bus_data_out_valid),
        .arbiter_req(init1_arbiter_req),
        .bus_mode(init1_bus_mode),
        .init_ack(init1_ack),
        .bus_init_ready(init1_bus_init_ready),
        .bus_init_rw(init1_bus_init_rw),
        .init_split_ack(init1_split_ack)
    );

    init_port u_init_port_2 (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(init2_req),
        .arbiter_grant(init2_arbiter_grant),
        .init_data_out(init2_data_out),
        .init_data_out_valid(init2_data_out_valid),
        .init_addr_out(init2_addr_out),
        .init_addr_out_valid(init2_addr_out_valid),
        .init_rw(init2_rw),
        .init_ready(init2_ready),
        .target_split(init2_target_split_int),
        .target_ack(init2_target_ack_int),
        .bus_data_in_valid(init2_bus_data_in_valid),
        .bus_data_in(init2_bus_data_in),
        .bus_data_out(init2_bus_data_out),
        .init_grant(init2_grant),
        .init_data_in(init2_data_in),
        .init_data_in_valid(init2_data_in_valid),
        .bus_data_out_valid(init2_bus_data_out_valid),
        .arbiter_req(init2_arbiter_req),
        .bus_mode(init2_bus_mode),
        .init_ack(init2_ack),
        .bus_init_ready(init2_bus_init_ready),
        .bus_init_rw(init2_bus_init_rw),
        .init_split_ack(init2_split_ack)
    );

    // Target ports
    target_port u_target_port_1 (
        .clk(clk),
        .rst_n(rst_n),
        .target_data_out(target1_data_out),
        .target_data_out_valid(target1_data_out_valid),
        .target_rw(target1_rw),
        .target_ready(target1_ready),
        .target_ack(target1_ack),
        .decoder_valid(target1_valid),
        .bus_data_in_valid(forward_valid),
        .bus_data_in(forward_data),
        .bus_mode(forward_mode),
        .bus_data_out(target1_bus_data_out),
        .target_data_in(target1_data_in),
        .target_data_in_valid(target1_data_in_valid),
        .target_addr_in(target1_addr_in),
        .target_addr_in_valid(target1_addr_in_valid),
        .bus_data_out_valid(target1_bus_data_out_valid),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_target_ack(target1_bus_target_ack)
    );

    target_port u_target_port_2 (
        .clk(clk),
        .rst_n(rst_n),
        .target_data_out(target2_data_out),
        .target_data_out_valid(target2_data_out_valid),
        .target_rw(target2_rw),
        .target_ready(target2_ready),
        .target_ack(target2_ack),
        .decoder_valid(target2_valid),
        .bus_data_in_valid(forward_valid),
        .bus_data_in(forward_data),
        .bus_mode(forward_mode),
        .bus_data_out(target2_bus_data_out),
        .target_data_in(target2_data_in),
        .target_data_in_valid(target2_data_in_valid),
        .target_addr_in(target2_addr_in),
        .target_addr_in_valid(target2_addr_in_valid),
        .bus_data_out_valid(target2_bus_data_out_valid),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_target_ack(target2_bus_target_ack)
    );

    split_target_port u_split_target_port (
        .clk(clk),
        .rst_n(rst_n),
        .split_req(split_target_req),
        .arbiter_grant(grant_split),
        .target_data_out(split_target_data_out),
        .target_data_out_valid(split_target_data_out_valid),
        .target_rw(split_target_rw),
        .target_ready(split_target_ready),
        .target_split_ack(split_target_split_ack),
        .target_ack(split_target_ack),
        .decoder_valid(target3_valid),
        .bus_data_in_valid(forward_valid),
        .bus_data_in(forward_data),
        .bus_mode(forward_mode),
        .bus_data_out(split_port_bus_data_out),
        .split_grant(split_target_grant),
        .target_data_in(split_target_data_in),
        .target_data_in_valid(split_target_data_in_valid),
        .target_addr_in(split_target_addr_in),
        .target_addr_in_valid(split_target_addr_in_valid),
        .bus_data_out_valid(split_port_bus_data_out_valid),
        .arbiter_split_req(split_port_arbiter_split_req),
        .split_ack(),
        .bus_target_ready(),
        .bus_target_rw(),
        .bus_split_ack(split_port_bus_split_ack),
        .bus_target_ack(split_port_bus_target_ack)
    );

    // Arbiter and decoder
    ot_arbiter u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_i_1(init1_arbiter_req),
        .req_i_2(init2_arbiter_req),
        .req_split(split_port_arbiter_split_req),
        .grant_i_1(grant_i1),
        .grant_i_2(grant_i2),
        .grant_split(grant_split),
        .sel(arb_sel_bits)
    );

    assign decoder_release = {target3_decoder_release, target2_decoder_release, target1_decoder_release};

    ot_addr_decoder #(
        .TARGET1_BASE(TARGET1_BASE),
        .TARGET1_SIZE(TARGET1_SIZE),
        .TARGET2_BASE(TARGET2_BASE),
        .TARGET2_SIZE(TARGET2_SIZE),
        .TARGET3_BASE(TARGET3_BASE),
        .TARGET3_SIZE(TARGET3_SIZE)
    ) u_addr_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .bus_data_in(forward_data),
        .bus_data_in_valid(forward_valid),
        .bus_mode(forward_mode),
        .release_valids(decoder_release),
        .target_1_valid(target1_valid),
        .target_2_valid(target2_valid),
        .target_3_valid(target3_valid),
        .sel(decoder_sel)
    );

    // Hold target selection until the transaction completes so the ports keep
    // seeing a stable decoder gate. Release occurs once an ACK has been seen
    // and the target is no longer driving return data.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target1_select_hold <= 1'b0;
            target2_select_hold <= 1'b0;
            target3_select_hold <= 1'b0;
            target1_release_pending <= 1'b0;
            target2_release_pending <= 1'b0;
            target3_release_pending <= 1'b0;
            target1_decoder_release <= 1'b0;
            target2_decoder_release <= 1'b0;
            target3_decoder_release <= 1'b0;
            target1_owner <= INIT_NONE;
            target2_owner <= INIT_NONE;
            target3_owner <= INIT_NONE;
            target1_expect_data <= 1'b0;
            target1_data_seen   <= 1'b0;
            target2_expect_data <= 1'b0;
            target2_data_seen   <= 1'b0;
            target3_expect_data <= 1'b0;
            target3_data_seen   <= 1'b0;
        end else begin
            target1_decoder_release <= 1'b0;
            target2_decoder_release <= 1'b0;
            target3_decoder_release <= 1'b0;

            // Target 1 hold management.
            if (target1_valid && !target1_select_hold) begin
                target1_select_hold <= 1'b1;
                target1_release_pending <= 1'b0;
                target1_expect_data <= (current_bus_rw == 1'b0);
                target1_data_seen   <= 1'b0;
                if (active_init != INIT_NONE)
                    target1_owner <= active_init;
            end

            if (target1_bus_target_ack)
                target1_release_pending <= 1'b1;

            if (target1_select_hold && target1_bus_data_out_valid)
                target1_data_seen <= 1'b1;

            if (target1_select_hold && target1_release_pending &&
                (!target1_expect_data || (target1_data_seen && !target1_bus_data_out_valid))) begin
                target1_select_hold <= 1'b0;
                target1_release_pending <= 1'b0;
                target1_decoder_release <= 1'b1;
                target1_owner <= INIT_NONE;
                target1_expect_data <= 1'b0;
                target1_data_seen   <= 1'b0;
            end

            // Target 2 mirrors target 1 behaviour.
            if (target2_valid && !target2_select_hold) begin
                target2_select_hold <= 1'b1;
                target2_release_pending <= 1'b0;
                target2_expect_data <= (current_bus_rw == 1'b0);
                target2_data_seen   <= 1'b0;
                if (active_init != INIT_NONE)
                    target2_owner <= active_init;
            end

            if (target2_bus_target_ack)
                target2_release_pending <= 1'b1;

            if (target2_select_hold && target2_bus_data_out_valid)
                target2_data_seen <= 1'b1;

            if (target2_select_hold && target2_release_pending &&
                (!target2_expect_data || (target2_data_seen && !target2_bus_data_out_valid))) begin
                target2_select_hold <= 1'b0;
                target2_release_pending <= 1'b0;
                target2_decoder_release <= 1'b1;
                target2_owner <= INIT_NONE;
                target2_expect_data <= 1'b0;
                target2_data_seen   <= 1'b0;
            end

            // Split target: release immediately on split-ACK or after the
            // deferred response has drained.
            if (target3_valid && !target3_select_hold) begin
                target3_select_hold <= 1'b1;
                target3_release_pending <= 1'b0;
                target3_expect_data <= (current_bus_rw == 1'b0);
                target3_data_seen   <= 1'b0;
                if (active_init != INIT_NONE)
                    target3_owner <= active_init;
            end

            if (split_port_bus_split_ack) begin
                target3_select_hold <= 1'b0;
                target3_release_pending <= 1'b0;
                target3_decoder_release <= 1'b1;
                target3_owner <= INIT_NONE;
                target3_expect_data <= 1'b0;
                target3_data_seen   <= 1'b0;
            end else begin
                if (split_port_bus_target_ack)
                    target3_release_pending <= 1'b1;

                if (target3_select_hold && split_port_bus_data_out_valid)
                    target3_data_seen <= 1'b1;

                if (target3_select_hold && target3_release_pending &&
                    (!target3_expect_data || (target3_data_seen && !split_port_bus_data_out_valid))) begin
                    target3_select_hold <= 1'b0;
                    target3_release_pending <= 1'b0;
                    target3_decoder_release <= 1'b1;
                    target3_owner <= INIT_NONE;
                    target3_expect_data <= 1'b0;
                    target3_data_seen   <= 1'b0;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_init <= INIT_NONE;
        end else begin
            if (grant_i1) begin
                active_init <= INIT_1;
            end else if (grant_i2) begin
                active_init <= INIT_2;
            end else if ((active_init == INIT_1 && !init1_arbiter_req) ||
                         (active_init == INIT_2 && !init2_arbiter_req)) begin
                active_init <= INIT_NONE;
            end
        end
    end

    // Forward bus multiplexing
    always_comb begin
        forward_data  = 1'b0;
        forward_valid = 1'b0;
        forward_mode  = 1'b0;

        if (grant_split) begin
            forward_mode = 1'b1;
        end else begin
            unique case (active_init)
                INIT_1: begin
                    forward_data  = init1_bus_data_out;
                    forward_valid = init1_bus_data_out_valid;
                    forward_mode  = init1_bus_mode;
                end
                INIT_2: begin
                    forward_data  = init2_bus_data_out;
                    forward_valid = init2_bus_data_out_valid;
                    forward_mode  = init2_bus_mode;
                end
                default: ;
            endcase
        end

    end

    // Track last requested direction so targets see a stable RW qualifier.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_bus_rw <= 1'b0;
        end else begin
            case (active_init)
                INIT_1: last_bus_rw <= init1_bus_init_rw;
                INIT_2: last_bus_rw <= init2_bus_init_rw;
                default: ;
            endcase
        end
    end

    always_comb begin
        unique case (active_init)
            INIT_1: current_bus_rw = init1_bus_init_rw;
            INIT_2: current_bus_rw = init2_bus_init_rw;
            default: current_bus_rw = last_bus_rw;
        endcase
    end

    assign target1_rw      = current_bus_rw;
    assign target2_rw      = current_bus_rw;
    assign split_target_rw = current_bus_rw;

    // Remember which initiator owns the pending split response.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            split_owner <= INIT_NONE;
            split_response_pending <= 1'b0;
        end else begin
            if (split_port_bus_split_ack) begin
                if (active_init != INIT_NONE)
                    split_owner <= active_init;
                else if (grant_i1)
                    split_owner <= INIT_1;
                else if (grant_i2)
                    split_owner <= INIT_2;
                split_response_pending <= 1'b1;
            end

            if (split_port_bus_target_ack)
                split_response_pending <= 1'b0;

            if (!split_response_pending &&
                !target3_select_hold &&
                !split_port_bus_data_out_valid &&
                !split_port_bus_target_ack) begin
                split_owner <= INIT_NONE;
            end
        end
    end

    assign split_route_active = (split_owner != INIT_NONE) &&
                                 (target3_select_hold || split_port_bus_data_out_valid || split_port_bus_target_ack);

    // Determine which target currently owns the return path.
        always_comb begin
            // Fall back to the currently active initiator when the owner register has not
            // latched yet, so first-cycle responses are not dropped.
            target1_owner_eff = target1_owner;
            if ((target1_owner_eff == INIT_NONE) && (active_init != INIT_NONE) &&
                (target1_select_hold || target1_valid))
                target1_owner_eff = active_init;

            target2_owner_eff = target2_owner;
            if ((target2_owner_eff == INIT_NONE) && (active_init != INIT_NONE) &&
                (target2_select_hold || target2_valid))
                target2_owner_eff = active_init;

            target3_owner_eff = target3_owner;
            if ((target3_owner_eff == INIT_NONE) && (active_init != INIT_NONE) &&
                (target3_select_hold || target3_valid))
                target3_owner_eff = active_init;
        end

    always_comb begin
        if (split_route_active)
            response_sel = 2'b10;
        else if (target3_select_hold)
            response_sel = 2'b10;
        else if (target2_select_hold)
            response_sel = 2'b01;
        else if (target1_select_hold)
            response_sel = 2'b00;
        else
            response_sel = 2'b00;
    end

    always_comb begin
        if (split_route_active) begin
            response_owner = split_owner;
        end else begin
            unique case (response_sel)
                    2'b10: response_owner = target3_owner_eff;
                    2'b01: response_owner = target2_owner_eff;
                    default: response_owner = target1_owner_eff;
            endcase
        end
    end

    // Backward path selection based on latched decoder outputs.
    always_comb begin
        response_data  = 1'b0;
        response_valid = 1'b0;
        response_ack   = 1'b0;

        unique case (response_sel)
            2'b10: begin
                response_data  = split_port_bus_data_out;
                response_valid = split_port_bus_data_out_valid;
                response_ack   = split_port_bus_target_ack;
            end
            2'b01: begin
                response_data  = target2_bus_data_out;
                response_valid = target2_bus_data_out_valid;
                response_ack   = target2_bus_target_ack;
            end
            default: begin
                response_data  = target1_bus_data_out;
                response_valid = target1_bus_data_out_valid;
                response_ack   = target1_bus_target_ack;
            end
        endcase
    end

    // Drive initiator-side return signals.
    always_comb begin
        init1_bus_data_in        = 1'b0;
        init1_bus_data_in_valid  = 1'b0;
        init1_target_ack_int     = 1'b0;
        init1_target_split_int   = 1'b0;

        init2_bus_data_in        = 1'b0;
        init2_bus_data_in_valid  = 1'b0;
        init2_target_ack_int     = 1'b0;
        init2_target_split_int   = 1'b0;

        case (response_owner)
            INIT_1: begin
                init1_bus_data_in       = response_data;
                init1_bus_data_in_valid = response_valid;
                init1_target_ack_int    = response_ack;
            end
            INIT_2: begin
                init2_bus_data_in       = response_data;
                init2_bus_data_in_valid = response_valid;
                init2_target_ack_int    = response_ack;
            end
            default: ;
        endcase

        if (split_port_bus_split_ack) begin
            case (active_init)
                INIT_1: init1_target_split_int = 1'b1;
                INIT_2: init2_target_split_int = 1'b1;
                default: begin
                    if (split_owner == INIT_1)
                        init1_target_split_int = 1'b1;
                    else if (split_owner == INIT_2)
                        init2_target_split_int = 1'b1;
                end
            endcase
        end
    end

    // Grant routing back to initiators.
    assign init1_arbiter_grant = grant_i1 | (grant_split && split_owner == INIT_1);
    assign init2_arbiter_grant = grant_i2 | (grant_split && split_owner == INIT_2);

endmodule
