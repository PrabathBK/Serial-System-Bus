//-----------------------------------------------------------------------------
// Module: addr_decoder
// Description: Address decoder for ADS serial bus
//              4-state FSM decoding device address and routing to slaves
//              Supports 3 slaves with ready checking and split transactions
//
// Parameters:
//   ADDR_WIDTH - Total address width (default: 16 bits)
//   DEVICE_ADDR_WIDTH - Device address width (default: 4 bits)
//
// Memory Map:
//   - Device 0 (2'b00): Slave 1 (2KB, 0x000-0x7FF)   - No split support
//   - Device 1 (2'b01): Slave 2 (4KB, 0x000-0xFFF)   - No split support
//   - Device 2 (2'b10): Slave 3 (4KB, 0x000-0xFFF)   - SPLIT transaction support
//
// Functionality:
//   - Receives device address serially from master (4 bits)
//   - Decodes address to select one of 3 slaves
//   - Validates slave address and checks slave ready status
//   - Sends acknowledgement (ack) if slave valid and ready
//   - Routes mvalid signal to selected slave
//   - Handles split transaction continuation via split_grant
//
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps

module addr_decoder #(
    parameter ADDR_WIDTH = 16,
    parameter DEVICE_ADDR_WIDTH = 4
)(
    input clk,
    input rstn,
    
    // Serial data from master
    input mwdata,                    // write data bus
    input mvalid,                    // valid from master
    
    // Split transaction signals
    input ssplit,                    // split signal from slave
    input split_grant,               // signal from arbiter ending split
    
    // Ready signals from slaves
    input sready1,
    input sready2,
    input sready3,
    
    // Valid signals going to slaves
    output mvalid1,
    output mvalid2,
    output mvalid3,
    
    // Slave select going to muxes
    output reg [1:0] ssel,
    
    // Acknowledgement going back to master
    output ack
);

    // Internal signals
    reg [DEVICE_ADDR_WIDTH-1:0] slave_addr;
    reg                         slave_en;           // Enable slave connection
    wire                        mvalid_out;
    wire                        slave_addr_valid;   // Valid slave address
    wire [2:0]                  sready;
    reg [3:0]                   counter;
    reg [DEVICE_ADDR_WIDTH-1:0] split_slave_addr;
    
    // Decoder to give the correct mvalid signals to slaves
    dec3 mvalid_decoder (
        .sel(ssel),
        .en(mvalid_out),
        .out1(mvalid1),
        .out2(mvalid2),
        .out3(mvalid3)
    );
    
    // States
    localparam IDLE    = 2'b00,
               ADDR    = 2'b01,    // Receive address from master
               CONNECT = 2'b10,    // Enable correct slave connection
               WAIT    = 2'b11;    // Wait for transaction complete
    
    // State variables
    reg [1:0] state, next_state;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE    : next_state = (mvalid) ? ADDR : ((split_grant) ? WAIT : IDLE);
            ADDR    : next_state = (counter == DEVICE_ADDR_WIDTH-1) ? CONNECT : ADDR;
            CONNECT : next_state = (slave_addr_valid) ? ((mvalid) ? WAIT : CONNECT) : IDLE;
            WAIT    : next_state = (sready[slave_addr] | ssplit) ? IDLE : WAIT;
            default : next_state = IDLE;
        endcase
    end
    
    // State transition logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Combinational assignments
    assign mvalid_out       = mvalid & slave_en;
    assign slave_addr_valid = (slave_addr < 3) & sready[slave_addr];  // check whether ready and valid
    assign ack              = (state == CONNECT) & slave_addr_valid;   // If address invalid, do not ack
    assign sready           = {sready3, sready2, sready1};
    
    // Sequential output logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            slave_addr       <= 'b0;
            slave_en         <= 0;
            counter          <= 'b0;
            ssel             <= 'b0;
            split_slave_addr <= 'b0;
        end
        else begin
            case (state)
                IDLE : begin
                    slave_en <= 0;
                    if (mvalid) begin  // Have to send data
                        slave_addr[0] <= mwdata;
                        counter       <= 1;
                    end else if (split_grant) begin
                        slave_addr <= split_slave_addr;
                        counter    <= 'b0;
                    end else begin
                        slave_addr <= slave_addr;
                        counter    <= 'b0;
                    end
                end
                //Master sends address serially - LSB First
                ADDR : begin  // Receive slave device address (LSB-first, continuing from bit 0)
                    slave_addr[counter] <= mwdata;
                    if (counter == DEVICE_ADDR_WIDTH-1) begin
                        counter <= 'b0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                CONNECT : begin
                    slave_en <= 1;
                    ssel     <= slave_addr[1:0];
                end
                
                WAIT : begin
                    slave_en <= 1;
                    ssel     <= slave_addr[1:0];
                    if (ssplit)
                        split_slave_addr <= slave_addr;
                    else
                        split_slave_addr <= split_slave_addr;
                end
                
                default: begin
                    slave_addr       <= slave_addr;
                    slave_en         <= slave_en;
                    counter          <= counter;
                    ssel             <= ssel;
                    split_slave_addr <= split_slave_addr;
                end
            endcase
        end
    end

endmodule
