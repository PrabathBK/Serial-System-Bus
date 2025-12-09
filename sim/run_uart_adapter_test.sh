#!/bin/bash
#==============================================================================
# File: run_uart_adapter_test.sh
# Description: Run UART adapter testbench simulation
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
echo -e "${GREEN}UART Adapter Test - xsim Simulation${NC}"
echo -e "${GREEN}========================================${NC}"

# Create simulation directory
mkdir -p $SIM_DIR
cd $SIM_DIR

# Clean previous simulation files
echo -e "${YELLOW}Cleaning previous simulation files...${NC}"
rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.vcd xvlog.log xelab.log xsim.log

echo -e "${YELLOW}Step 1: Analyzing RTL files with xvlog...${NC}"

# Compile adapter modules
xvlog -sv \
    $RTL_DIR/uart_to_other_team_tx_adapter.v \
    $RTL_DIR/uart_to_other_team_rx_adapter.v

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: RTL compilation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}RTL compilation successful!${NC}"

echo -e "${YELLOW}Step 2: Analyzing testbench with xvlog...${NC}"

# Compile SystemVerilog testbench
xvlog -sv $TB_DIR/tb_uart_adapters.sv

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Testbench compilation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Testbench compilation successful!${NC}"

echo -e "${YELLOW}Step 3: Elaborating design with xelab...${NC}"

# Elaborate the design
xelab -debug typical tb_uart_adapters -s tb_uart_adapters_sim

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Elaboration failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Elaboration successful!${NC}"

echo -e "${YELLOW}Step 4: Running simulation with xsim...${NC}"

# Run simulation
xsim tb_uart_adapters_sim -runall

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Simulation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simulation completed!${NC}"
echo -e "${GREEN}========================================${NC}"

# Check for waveform file
if [ -f "tb_uart_adapters.vcd" ]; then
    echo -e "${GREEN}Waveform file generated: tb_uart_adapters.vcd${NC}"
    echo -e "${YELLOW}View with: gtkwave tb_uart_adapters.vcd${NC}"
fi

exit 0
