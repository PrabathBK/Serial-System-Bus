#!/bin/bash
#==============================================================================
# File: run_simple_test.sh
# Description: Run simple read test simulation for debugging
#==============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$SCRIPT_DIR/.."
RTL_DIR="$ROOT_DIR/rtl/core"
TB_DIR="$ROOT_DIR/tb"
SIM_DIR="$ROOT_DIR/sim"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simple Read Test - xsim Simulation${NC}"
echo -e "${GREEN}========================================${NC}"

# Create simulation directory
mkdir -p $SIM_DIR
cd $SIM_DIR

# Clean previous simulation files
echo -e "${YELLOW}Cleaning previous simulation files...${NC}"
rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.vcd xvlog.log xelab.log xsim.log

echo -e "${YELLOW}Step 1: Analyzing RTL files with xvlog...${NC}"

# Compile Verilog RTL files in dependency order
xvlog -sv \
    $RTL_DIR/dec3.v \
    $RTL_DIR/mux2.v \
    $RTL_DIR/mux3.v \
    $RTL_DIR/master_port.v \
    $RTL_DIR/slave_port.v \
    $RTL_DIR/arbiter.v \
    $RTL_DIR/addr_decoder.v \
    $RTL_DIR/slave_memory_bram.v \
    $RTL_DIR/slave.v \
    $RTL_DIR/bus_m2_s3.v

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: RTL compilation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}RTL compilation successful!${NC}"

echo -e "${YELLOW}Step 2: Analyzing testbench with xvlog...${NC}"

# Compile SystemVerilog testbench
xvlog -sv $TB_DIR/simple_read_test.sv

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Testbench compilation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Testbench compilation successful!${NC}"

echo -e "${YELLOW}Step 3: Elaborating design with xelab...${NC}"

# Elaborate the design
xelab -debug typical simple_read_test -s simple_read_test_sim

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Elaboration failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Elaboration successful!${NC}"

echo -e "${YELLOW}Step 4: Running simulation with xsim...${NC}"

# Run simulation
xsim simple_read_test_sim -runall

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Simulation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simulation completed!${NC}"
echo -e "${GREEN}========================================${NC}"

# Check for waveform file
if [ -f "simple_read_test.vcd" ]; then
    echo -e "${GREEN}Waveform file generated: simple_read_test.vcd${NC}"
    echo -e "${YELLOW}View with: gtkwave simple_read_test.vcd${NC}"
fi

exit 0
