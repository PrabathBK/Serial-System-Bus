//-----------------------------------------------------------------------------
// Module: arbiter
// Description: Priority-based arbiter for 2-master ADS serial bus
//              3-state FSM with split transaction support
//              Master 1 has priority over Master 2
//
// Functionality:
//   - Arbitrates bus access between 2 masters
//   - Master 1 (breq1) has higher priority than Master 2 (breq2)
//   - Handles split transactions from split-enabled slave
//   - Tracks split owner (SM1 or SM2)
//   - Grants access to continue split when slave is ready
//   - Allows non-split slaves to operate while split pending
//
// Target: Intel Cyclone V (Terasic DE10-Nano)
//-----------------------------------------------------------------------------

//NOTE
//A split transaction happens when a slave cannot finish an operation immediately and tells the master:
//"I am not ready. Release the bus. Come back later."
//Non- split slave --> Everyone waits. Bus is blocked.
//split slave --> Bus stays productive. No stalls.

`timescale 1ns / 1ps

module arbiter (
    input clk,
    input rstn,
    
    // Bus requests from 2 masters
    input breq1,
    input breq2,
    
    // Slave ready signals
    input sready1,          // slave 1 ready
    input sready2,          // slave 2 ready
    input sreadysp,         // split-supported slave ready
    
    // Split signal from slave
    input ssplit,
    
    // Bus grant signals for 2 masters
    output bgrant1,
    output bgrant2,
    
    // Master select: 0 - master 1, 1 - master 2
    output msel,
    
    // Split signals given to masters
    output reg msplit1,
    output reg msplit2,
    
    // Grant access to continue split transaction (send back to slave)
    output reg split_grant
);

    // Priority based: high priority for master 1 - breq1
    wire sready, sready_nsplit;
    reg [1:0] split_owner;
    
    assign sready        = sready1 & sready2 & sreadysp;
    assign sready_nsplit = sready1 & sready2;  // non-split slaves are ready
    
    // Split owner encoding
    localparam NONE = 2'b00,
               SM1  = 2'b01,
               SM2  = 2'b10;
    
    // States
    localparam IDLE = 3'b000,
               M1   = 3'b001,    // M1 uses bus
               M2   = 3'b010;    // M2 uses bus
    
    // State variables
    reg [2:0] state, next_state;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE : begin
                if (!ssplit) begin  // either split was released or no split was there
                    if (split_owner == SM1) 
                        next_state = M1;
                    else if (breq1 & sready) 
                        next_state = M1;
                    else if (split_owner == SM2) 
                        next_state = M2;
                    else if (breq2 & sready) 
                        next_state = M2;
                    else 
                        next_state = IDLE;
                end
                else begin
                    // One master is waiting for a split transaction, other master can continue
                    if ((split_owner == SM1) && breq2 && sready_nsplit) 
                        next_state = M2;
                    else if ((split_owner == SM2) && breq1 && sready_nsplit) 
                        next_state = M1;
                    else 
                        next_state = IDLE;
                end
            end
            
            M1 : next_state = (!breq1 | (split_owner == NONE && ssplit)) ? IDLE : M1;
            M2 : next_state = (!breq2 | (split_owner == NONE && ssplit)) ? IDLE : M2;
            
            default: next_state = IDLE;
        endcase
    end
    
    // State transition logic
    always @(posedge clk) begin
        state <= (!rstn) ? IDLE : next_state;
    end
    
    // Combinational output assignments
    assign bgrant1 = (state == M1);
    assign bgrant2 = (state == M2);
    assign msel    = (state == M2);
    
    // Sequential output assignments (for split)
    always @(posedge clk) begin
        if (!rstn) begin
            msplit1      <= 1'b0;
            msplit2      <= 1'b0;
            split_owner  <= NONE;
            split_grant  <= 1'b0;
        end
        else begin
            case (state)
                M1 : begin
                    if (split_owner == NONE && ssplit) begin
                        msplit1     <= 1'b1;
                        split_owner <= SM1;
                        split_grant <= 1'b0;
                    end else if (split_owner == SM1 && !ssplit) begin
                        msplit1     <= 1'b0;
                        split_owner <= NONE;
                        split_grant <= 1'b1;
                    end else begin
                        msplit1     <= msplit1;
                        split_owner <= split_owner;
                        split_grant <= 1'b0;
                    end
                end
                
                M2 : begin
                    if (split_owner == NONE && ssplit) begin
                        msplit2     <= 1'b1;
                        split_owner <= SM2;
                        split_grant <= 1'b0;
                    end else if (split_owner == SM2 && !ssplit) begin
                        msplit2     <= 1'b0;
                        split_owner <= NONE;
                        split_grant <= 1'b1;
                    end else begin
                        msplit2     <= msplit2;
                        split_owner <= split_owner;
                        split_grant <= 1'b0;
                    end
                end
                
                default : begin
                    msplit1     <= msplit1;
                    msplit2     <= msplit2;
                    split_owner <= split_owner;
                    split_grant <= split_grant;
                end
            endcase
        end
    end

endmodule
