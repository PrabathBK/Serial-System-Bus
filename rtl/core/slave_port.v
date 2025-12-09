//-----------------------------------------------------------------------------
// Module: slave_port
// Description: Slave port interface for ADS serial bus system
//              8-state FSM handling slave-side serial transactions
//              Configurable split transaction support
//
// Parameters:
//   ADDR_WIDTH - Address width (default: 12 bits for slave memory)
//   DATA_WIDTH - Data width (default: 8 bits)
//   SPLIT_EN   - Enable split transaction support (0 or 1)
//
// Functionality:
//   - Receives address and data serially from master
//   - Interfaces with slave memory (BRAM)
//   - Sends read data serially to master
//   - Optional split transaction with configurable latency
//   - Ready signal indicates availability for new transaction
//
// Author: ADS Bus System Generator
// Target: Intel Cyclone IV EP4CE22F17C6 (DE0-Nano)
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps

module slave_port #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 8,
    parameter SPLIT_EN = 0
)(
    input clk,
    input rstn,
    
    // Signals connecting to slave memory
    input  [DATA_WIDTH-1:0] smemrdata,    // data read from the slave memory
    input                   rvalid,       // read data is available
    output reg              smemwen,      // write enable
    output reg              smemren,      // read enable
    output reg [ADDR_WIDTH-1:0] smemaddr, // slave memory address
    output reg [DATA_WIDTH-1:0] smemwdata,// data written to the slave memory
    
    // Signals connecting to serial bus
    input                   swdata,       // write data and address from master
    output reg              srdata,       // read data to the master
    input                   smode,        // 0 - read, 1 - write
    input                   mvalid,       // wdata valid (receiving data and address from master)
    input                   split_grant,  // grant to send read data
    output reg              svalid,       // rdata valid (sending data from slave)
    output                  sready,       // slave is ready for transaction
    output                  ssplit        // 1 - split
);

    /* Internal signals */
    // Registers to accept data from master and slave memory
    reg [DATA_WIDTH-1:0] wdata;         // write data from master
    reg [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] rdata;
    reg mode;
    
    // Counters
    reg [7:0] counter;
    
    // Read data from slave memory with latency
    localparam LATENCY = 4;
    reg [LATENCY-1:0] rcounter;
    
    // States
    localparam IDLE   = 3'b000,
               ADDR   = 3'b001,    // Receive address from master
               RDATA  = 3'b010,    // Send data to master
               WDATA  = 3'b011,    // Receive data from master
               SREADY = 3'b101,    // Slave ready
               SPLIT  = 3'b100,    // Split transaction
               WAIT   = 3'b110,    // Wait for split grant
               RVALID = 3'b111;    // Wait for read data valid
    
    // State variables
    reg [2:0] state, next_state, prev_state;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE   : next_state = (mvalid) ? ADDR : IDLE;
            ADDR   : next_state = (counter == ADDR_WIDTH-1) ? ((mode) ? WDATA : SREADY) : ADDR;
            SREADY : next_state = (mode) ? IDLE : ((SPLIT_EN) ? SPLIT : RVALID);
            RVALID : next_state = (rvalid) ? RDATA : RVALID;
            SPLIT  : next_state = (rcounter == LATENCY) ? WAIT : SPLIT;
            WAIT   : next_state = (split_grant) ? RDATA : WAIT;
            RDATA  : next_state = (counter == DATA_WIDTH * 2) ? IDLE : RDATA;
            WDATA  : next_state = (counter == DATA_WIDTH-1) ? SREADY : WDATA;
            default: next_state = IDLE;
        endcase
    end
    
    // State transition logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            prev_state <= IDLE;
        end else begin
            if (state != next_state) begin
                $display("[SLAVE_PORT %m @%0t] STATE TRANSITION: %0s -> %0s, mode=%b, mvalid=%b, smode=%b",
                         $time, 
                         state == IDLE ? "IDLE" : state == ADDR ? "ADDR" : state == RDATA ? "RDATA" :
                         state == WDATA ? "WDATA" : state == SREADY ? "SREADY" : state == SPLIT ? "SPLIT" :
                         state == WAIT ? "WAIT" : state == RVALID ? "RVALID" : "UNKNOWN",
                         next_state == IDLE ? "IDLE" : next_state == ADDR ? "ADDR" : next_state == RDATA ? "RDATA" :
                         next_state == WDATA ? "WDATA" : next_state == SREADY ? "SREADY" : next_state == SPLIT ? "SPLIT" :
                         next_state == WAIT ? "WAIT" : next_state == RVALID ? "RVALID" : "UNKNOWN",
                         mode, mvalid, smode);
            end
            prev_state <= state;
            state <= next_state;
        end
    end
    
    // Combinational output assignments
    assign rdata  = smemrdata;
    assign sready = (state == IDLE);
    assign ssplit = (state == SPLIT);
    
    // Sequential output logic (async reset)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wdata    <= 'b0;
            addr     <= 'b0;
            counter  <= 'b0;
            svalid   <= 0;
            smemren  <= 0;
            smemwen  <= 0;
            mode     <= 0;
            smemaddr <= 0;
            smemwdata<= 0;
            srdata   <= 0;
            rcounter <= 'b0;
        end
        else begin
            case (state)
                IDLE : begin
                    counter <= 'b0;
                    svalid  <= 0;
                    smemren <= 0;
                    smemwen <= 0;
                    if (mvalid) begin
                        mode <= smode;
                        addr[counter] <= swdata;
                        counter <= counter + 1;
                        $display("[SLAVE_PORT %m @%0t] IDLE: Latching mode=%b (smode=%b), receiving first addr bit=%b", 
                                 $time, smode, smode, swdata);
                    end else begin
                        addr    <= addr;
                        counter <= counter;
                        mode    <= mode;
                    end
                end
                
                ADDR : begin
                    svalid <= 1'b0;
                    if (mvalid) begin
                        addr[counter] <= swdata;
                        if (counter == ADDR_WIDTH-1) begin
                            counter <= 'b0;
                        end else begin
                            counter <= counter + 1;
                        end
                    end else begin
                        addr    <= addr;
                        counter <= counter;
                    end
                end
                
                SREADY: begin
                    svalid <= 1'b0;
                    if (mode) begin
                        smemwen   <= 1'b1;
                        smemwdata <= wdata;
                        smemaddr  <= addr;
                        $display("[SLAVE_PORT @%0t] SREADY state (WRITE): addr=0x%h, wdata=0x%h", $time, addr, wdata);
                    end else begin
                        smemren  <= 1'b1;
                        smemaddr <= addr;
                        $display("[SLAVE_PORT @%0t] SREADY state (READ): addr=0x%h, starting read", $time, addr);
                    end
                end
                
                RVALID: begin
                    // Waiting for read data valid - keep smemren asserted
                    smemren <= 1'b1;
                    $display("[SLAVE_PORT @%0t] RVALID state: smemren=%b, rvalid=%b, smemrdata=0x%h, smemaddr=0x%h", 
                             $time, smemren, rvalid, smemrdata, smemaddr);
                end
                
                SPLIT : begin  // Wait for some time - keep smemren asserted
                    rcounter <= rcounter + 1;
                    smemren <= 1'b1;
                end
                
                WAIT : begin  // Wait until grant bus access for split transfer - keep smemren asserted
                    rcounter <= 'b0;
                    smemren <= 1'b1;
                end
                
                RDATA : begin  // Send data to master
                    // Strategy: Each bit needs 2 cycles - one to load, one to hold for master to sample
                    // counter[0] = 0 (even): Load bit into srdata, svalid=0
                    // counter[0] = 1 (odd):  Hold bit in srdata, svalid=1 (master samples next clock edge)
                    //
                    // Timeline:
                    // counter=0: Load bit[0], svalid=0
                    // counter=1: Hold bit[0], svalid=1 -> master samples bit[0] at next edge
                    // counter=2: Load bit[1], svalid=0
                    // counter=3: Hold bit[1], svalid=1 -> master samples bit[1] at next edge
                    // ...
                    // counter=14: Load bit[7], svalid=0
                    // counter=15: Hold bit[7], svalid=1 -> master samples bit[7] at next edge
                    // counter=16: Exit
                    
                    if (counter < DATA_WIDTH * 2) begin
                        if (counter[0] == 0) begin
                            // Even counter: Load bit
                            srdata <= rdata[counter >> 1];  // counter/2 gives bit index
                            svalid <= 1'b0;
                            if (counter == 0)
                                $display("[SLAVE_PORT %m @%0t] RDATA transmission START, data=0x%h", $time, rdata);
                            //$display("[SLAVE_PORT @%0t] RDATA counter=%0d: loading bit[%0d]=%b, svalid=0", 
                            //         $time, counter, counter>>1, rdata[counter>>1]);
                        end else begin
                            // Odd counter: Hold bit, assert valid
                            svalid <= 1'b1;
                            if (counter == 15)
                                $display("[SLAVE_PORT %m @%0t] RDATA transmission END (sending last bit)", $time);
                            //$display("[SLAVE_PORT @%0t] RDATA counter=%0d: holding bit[%0d]=%b, svalid=1", 
                            //         $time, counter, counter>>1, srdata);
                        end
                        smemren <= 1'b1;
                        counter <= counter + 1;
                    end else begin
                        // Transmission complete
                        svalid <= 1'b0;
                        smemren <= 1'b0;
                        counter <= 'b0;
                    end
                end
                
                WDATA : begin  // Receive data from master
                    $display("[SLAVE_PORT %m @%0t] WDATA state: prev_state=%0d, state=%0d, mvalid=%b, counter=%0d, swdata=%b", 
                             $time, prev_state, state, mvalid, counter, swdata);
                    svalid <= 1'b0;
                    // Skip sampling on first cycle after transition from ADDR (setup time for data)
                    if (mvalid && !(prev_state == ADDR && state == WDATA)) begin
                        wdata[counter] <= swdata;
                        $display("[SLAVE_PORT %m @%0t] WDATA receiving: bit[%0d]=%b, swdata=%b, current_wdata=0x%h", 
                                 $time, counter, swdata, swdata, wdata);
                        if (counter == DATA_WIDTH-1) begin
                            // DON'T set smemwen here - let SREADY do it with smemaddr at the same time
                            // This ensures both signals are set together via non-blocking assignment
                            counter <= 'b0;
                            $display("[SLAVE_PORT %m @%0t] WDATA COMPLETE: will write 0x%h to memory", 
                                     $time, {wdata[DATA_WIDTH-2:0], swdata});
                        end else begin
                            counter <= counter + 1;
                        end
                    end else begin
                        wdata   <= wdata;
                        counter <= counter;
                        if (prev_state == ADDR && state == WDATA) begin
                            $display("[SLAVE_PORT %m @%0t] WDATA setup cycle (SKIPPING first sample, prev=%0d, state=%0d)", 
                                     $time, prev_state, state);
                        end
                    end
                end
                
                default: begin
                    wdata    <= wdata;
                    addr     <= addr;
                    counter  <= counter;
                    svalid   <= svalid;
                    smemwen  <= smemwen;
                    smemren  <= smemren;
                    rcounter <= rcounter;
                end
            endcase
        end
    end

endmodule
