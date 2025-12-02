#!/bin/bash
# Run comprehensive bus bridge testbench v2
# This script compiles and simulates the testbench using Xilinx Vivado XSIM

# Change to sim directory
cd "$(dirname "$0")"

echo "=============================================="
echo "Bus Bridge Testbench v2 - Compilation & Simulation"
echo "=============================================="

# Clean previous simulation files
echo "Cleaning previous simulation files..."
rm -rf xsim.dir
rm -f *.log *.jou *.pb *.wdb *.vcd

# Compile all Verilog files
echo ""
echo "Compiling RTL files..."
xvlog --sv \
    ../rtl/core/fifo.v \
    ../rtl/core/uart_tx.v \
    ../rtl/core/uart_rx.v \
    ../rtl/core/uart.v \
    ../rtl/core/addr_convert.v \
    ../rtl/core/addr_decoder.v \
    ../rtl/core/dec3.v \
    ../rtl/core/mux2.v \
    ../rtl/core/mux3.v \
    ../rtl/core/arbiter.v \
    ../rtl/core/slave_memory_bram.v \
    ../rtl/core/master_memory_bram.v \
    ../rtl/core/slave_port.v \
    ../rtl/core/master_port.v \
    ../rtl/core/slave.v \
    ../rtl/core/master.v \
    ../rtl/core/bus_bridge_slave_v2.v \
    ../rtl/core/bus_bridge_master_v2.v \
    ../rtl/core/bus_m2_s3.v \
    ../tb/bus_bridge_tb_v2.sv \
    2>&1 | tee compile.log

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

# Elaborate the design
echo ""
echo "Elaborating design..."
xelab -debug typical bus_bridge_tb_v2 -s bus_bridge_tb_v2_sim 2>&1 | tee elab.log

if [ $? -ne 0 ]; then
    echo "ERROR: Elaboration failed!"
    exit 1
fi

# Run simulation
echo ""
echo "Running simulation..."
xsim bus_bridge_tb_v2_sim -runall 2>&1 | tee sim.log

echo ""
echo "=============================================="
echo "Simulation complete!"
echo "=============================================="
echo "Output files:"
echo "  - compile.log: Compilation output"
echo "  - elab.log: Elaboration output"
echo "  - sim.log: Simulation output"
echo "  - bus_bridge_tb_v2.vcd: Waveform file"
echo "=============================================="
