//==============================================================================
// File: bus_m2_s3.v
// Description: Top-level bus interconnect for 2 masters and 3 slaves
//              Contains arbiter, address decoder, and routing multiplexers
//              Implements priority-based arbitration (M1 > M2)
//              
// Memory Configuration:
//   - Slave 1: 2KB (0x000-0x7FF)   - No split support
//   - Slave 2: 4KB (0x000-0xFFF)   - No split support  
//   - Slave 3: 4KB (0x000-0xFFF)   - SPLIT transaction support
//
// Device Addressing:
//   - Device 0 (2'b00): Slave 1 (2KB)
//   - Device 1 (2'b01): Slave 2 (4KB)
//   - Device 2 (2'b10): Slave 3 (4KB, Split)
//==============================================================================
// Author: ADS Bus System
// Date: 2025-10-14
//==============================================================================


`timescale 1ns / 1ps

module bus_m2_s3 #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter SLAVE1_MEM_ADDR_WIDTH = 11,  // 2KB = 2^11 bytes
    parameter SLAVE2_MEM_ADDR_WIDTH = 12,  // 4KB = 2^12 bytes
    parameter SLAVE3_MEM_ADDR_WIDTH = 12   // 4KB = 2^12 bytes
)(
    // Global signals
    input  wire clk,
    input  wire rstn,

    //--------------------------------------------------------------------------
    // Master 1 Interface
    //--------------------------------------------------------------------------
    output wire m1_rdata,       // Read data
    input  wire m1_wdata,       // Write data and address
    input  wire m1_mode,        // 0 - read, 1 - write
    input  wire m1_mvalid,      // wdata valid
    output wire m1_svalid,      // rdata valid
    input  wire m1_breq,        // Bus request
    output wire m1_bgrant,      // Bus grant
    output wire m1_ack,         // Acknowledgement
    output wire m1_split,       // Split signal

    //--------------------------------------------------------------------------
    // Master 2 Interface
    //--------------------------------------------------------------------------
    output wire m2_rdata,       // Read data
    input  wire m2_wdata,       // Write data and address
    input  wire m2_mode,        // 0 - read, 1 - write
    input  wire m2_mvalid,      // wdata valid
    output wire m2_svalid,      // rdata valid
    input  wire m2_breq,        // Bus request
    output wire m2_bgrant,      // Bus grant
    output wire m2_ack,         // Acknowledgement
    output wire m2_split,       // Split signal

    //--------------------------------------------------------------------------
    // Slave 1 Interface
    //--------------------------------------------------------------------------
    input  wire s1_rdata,       // Read data
    output wire s1_wdata,       // Write data and address
    output wire s1_mode,        // 0 - read, 1 - write
    output wire s1_mvalid,      // wdata valid
    input  wire s1_svalid,      // rdata valid
    input  wire s1_ready,       // Slave ready

    //--------------------------------------------------------------------------
    // Slave 2 Interface
    //--------------------------------------------------------------------------
    input  wire s2_rdata,       // Read data
    output wire s2_wdata,       // Write data and address
    output wire s2_mode,        // 0 - read, 1 - write
    output wire s2_mvalid,      // wdata valid
    input  wire s2_svalid,      // rdata valid
    input  wire s2_ready,       // Slave ready

    //--------------------------------------------------------------------------
    // Slave 3 Interface (Split-capable)
    //--------------------------------------------------------------------------
    input  wire s3_rdata,       // Read data
    output wire s3_wdata,       // Write data and address
    output wire s3_mode,        // 0 - read, 1 - write
    output wire s3_mvalid,      // wdata valid
    input  wire s3_svalid,      // rdata valid
    input  wire s3_ready,       // Slave ready
    input  wire s3_split,       // Split transaction signal

    //--------------------------------------------------------------------------
    // Split Transaction Control
    //--------------------------------------------------------------------------
    output wire split_grant     // Grant to continue split transaction
);

    //--------------------------------------------------------------------------
    // Local Parameters
    //--------------------------------------------------------------------------
    // Device address width is calculated from largest slave address width
    localparam MAX_SLAVE_ADDR_WIDTH = (SLAVE1_MEM_ADDR_WIDTH > SLAVE2_MEM_ADDR_WIDTH) ? 
                                      ((SLAVE1_MEM_ADDR_WIDTH > SLAVE3_MEM_ADDR_WIDTH) ? SLAVE1_MEM_ADDR_WIDTH : SLAVE3_MEM_ADDR_WIDTH) :
                                      ((SLAVE2_MEM_ADDR_WIDTH > SLAVE3_MEM_ADDR_WIDTH) ? SLAVE2_MEM_ADDR_WIDTH : SLAVE3_MEM_ADDR_WIDTH);
    localparam DEVICE_ADDR_WIDTH = ADDR_WIDTH - MAX_SLAVE_ADDR_WIDTH;

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    // Master muxed signals (output of master selection)
    wire m_wdata;               // Selected master write data
    wire m_mode;                // Selected master mode
    wire m_mvalid;              // Selected master valid
    wire m_select;              // Master select (0=M1, 1=M2)
    
    // Address decoder signals
    wire [1:0] s_select;        // Slave select (00=S1, 01=S2, 10=S3)
    wire m_ack;                 // Acknowledgement from decoder
    
    // Slave muxed signals (output of slave selection)
    wire s_rdata;               // Selected slave read data
    wire s_svalid;              // Selected slave valid
    wire s_split;               // Selected slave split signal

    //==========================================================================
    // Bus Arbiter Instantiation
    //==========================================================================
    arbiter bus_arbiter (
        .clk(clk),
        .rstn(rstn),
        
        // Master requests
        .breq1(m1_breq),
        .breq2(m2_breq),
        
        // Master grants
        .bgrant1(m1_bgrant),
        .bgrant2(m2_bgrant),
        
        // Master select output
        .msel(m_select),
        
        // Slave ready signals
        .sready1(s1_ready),
        .sready2(s2_ready),
        .sreadysp(s3_ready),
        
        // Split transaction signals
        .ssplit(s_split),
        .msplit1(m1_split),
        .msplit2(m2_split),
        .split_grant(split_grant)
    );

    //==========================================================================
    // Address Decoder Instantiation
    //==========================================================================
    addr_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEVICE_ADDR_WIDTH(DEVICE_ADDR_WIDTH)
    ) decoder (
        .clk(clk),
        .rstn(rstn),
        
        // Master write data and valid
        .mwdata(m_wdata),
        .mvalid(m_mvalid),
        
        // Slave valid outputs
        .mvalid1(s1_mvalid),
        .mvalid2(s2_mvalid),
        .mvalid3(s3_mvalid),
        
        // Slave ready inputs
        .sready1(s1_ready),
        .sready2(s2_ready),
        .sready3(s3_ready),
        
        // Slave select and acknowledgement
        .ssel(s_select),
        .ack(m_ack),
        
        // Split transaction signals
        .ssplit(s_split),
        .split_grant(split_grant)
    );

    //==========================================================================
    // Master-Side Multiplexers (2:1 MUX - Select between M1 and M2)
    //==========================================================================
    
    // Write data mux
    mux2 #(.WIDTH(1)) wdata_mux (
        .sel(m_select),
        .in0(m1_wdata),
        .in1(m2_wdata),
        .out(m_wdata)
    );

    // Master control signals mux (mode and mvalid)
    mux2 #(.WIDTH(2)) mctrl_mux (
        .sel(m_select),
        .in0({m1_mode, m1_mvalid}),
        .in1({m2_mode, m2_mvalid}),
        .out({m_mode, m_mvalid})
    );

    //==========================================================================
    // Slave-Side Multiplexers (3:1 MUX - Select between S1, S2, and S3)
    //==========================================================================
    
    // Read data mux
    mux3 #(.WIDTH(1)) rdata_mux (
        .sel(s_select),
        .in0(s1_rdata),
        .in1(s2_rdata),
        .in2(s3_rdata),
        .out(s_rdata)
    );

    // Read control signals mux (svalid)
    mux3 #(.WIDTH(1)) rctrl_mux (
        .sel(s_select),
        .in0(s1_svalid),
        .in1(s2_svalid),
        .in2(s3_svalid),
        .out(s_svalid)
    );

    //==========================================================================
    // Signal Assignments - Broadcast and Distribution
    //==========================================================================
    
    // Master read data and control (broadcast selected slave signals to both masters)
    assign m1_rdata  = s_rdata;
    assign m1_svalid = s_svalid;
    assign m2_rdata  = s_rdata;
    assign m2_svalid = s_svalid;
    
    // Slave write data and control (broadcast selected master signals to all slaves)
    assign s1_wdata  = m_wdata;
    assign s1_mode   = m_mode;
    assign s2_wdata  = m_wdata;
    assign s2_mode   = m_mode;
    assign s3_wdata  = m_wdata;
    assign s3_mode   = m_mode;
    
    // Master acknowledgement (broadcast to both masters)
    assign m1_ack    = m_ack;
    assign m2_ack    = m_ack;
    
    // Split signal (from S3 only, as it's the split-capable slave)
    assign s_split   = s3_split;

endmodule
