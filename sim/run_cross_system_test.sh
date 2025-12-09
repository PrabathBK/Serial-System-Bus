#!/bin/bash
#===================================================================
# run_cross_system_test.sh - Cross-System UART Bridge Test Runner
# Description: Simulates two FPGA systems connected via UART adapters
# Date: 2025-12-09
# Author: ADS Team
#===================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Cross-System UART Bridge Test${NC}"
echo -e "${YELLOW}========================================${NC}"

# Create work directory if it doesn't exist
if [ ! -d "xsim.dir" ]; then
    echo -e "${YELLOW}Creating work directory...${NC}"
fi

# Clean previous simulation files
rm -f tb_cross_system_with_adapters.vcd
rm -f xsim.log
rm -f webtalk*.jou webtalk*.log

echo -e "${YELLOW}Analyzing Verilog source files...${NC}"

# Analyze RTL files - Your system (ADS)
xvlog -sv \
    rtl/core/fifo.v \
    rtl/core/arbiter.v \
    rtl/core/addr_decoder.v \
    rtl/core/mux2.v \
    rtl/core/mux3.v \
    rtl/core/dec3.v \
    rtl/core/slave.v \
    rtl/core/slave_port.v \
    rtl/core/master_port.v \
    rtl/core/addr_convert.v \
    rtl/core/slave_memory_bram.v \
    rtl/core/master_memory_bram.v \
    rtl/core/bus_m2_s3.v \
    rtl/core/uart_tx.v \
    rtl/core/uart_rx.v \
    rtl/core/uart.v \
    rtl/core/bus_bridge_master.v \
    rtl/core/bus_bridge_slave.v \
    rtl/core/uart_to_other_team_tx_adapter.v \
    rtl/core/uart_to_other_team_rx_adapter.v \
    rtl/demo_uart_bridge.v

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: ADS system analysis failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Analyzing other team's system files...${NC}"

# Analyze RTL files - Other team's system
xvlog -sv \
    another_team/serial-bus-design/rtl/uart/buadrate.v \
    another_team/serial-bus-design/rtl/uart/receiver.v \
    another_team/serial-bus-design/rtl/uart/transmitter.v \
    another_team/serial-bus-design/rtl/uart/uart.v \
    another_team/serial-bus-design/rtl/bus_bridge_pkg.sv \
    another_team/serial-bus-design/rtl/target.sv \
    another_team/serial-bus-design/rtl/split_target.sv \
    another_team/serial-bus-design/rtl/initiator.sv \
    another_team/serial-bus-design/rtl/target_port.sv \
    another_team/serial-bus-design/rtl/split_target_port.sv \
    another_team/serial-bus-design/rtl/init_port.sv \
    another_team/serial-bus-design/rtl/arbiter.sv \
    another_team/serial-bus-design/rtl/addr_decoder.sv \
    another_team/serial-bus-design/rtl/bus.sv \
    another_team/serial-bus-design/rtl/bus_bridge_initiator_if.sv \
    another_team/serial-bus-design/rtl/bus_bridge_target_if.sv \
    another_team/serial-bus-design/rtl/bus_bridge.sv \
    another_team/serial-bus-design/rtl/bus_bridge_initiator_uart_wrapper.sv \
    another_team/serial-bus-design/rtl/bus_bridge_target_uart_wrapper.sv \
    another_team/serial-bus-design/rtl/system_top_with_bus_bridge_b.sv

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Other team system analysis failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Analyzing testbench...${NC}"

# Analyze testbench
xvlog -sv tb/tb_cross_system_with_adapters.sv

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Testbench analysis failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Elaborating design...${NC}"

# Elaborate
xelab -debug typical tb_cross_system_with_adapters -s tb_cross_system_with_adapters_sim

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Elaboration failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Running simulation...${NC}"
echo -e "${YELLOW}Note: This may take several minutes due to UART timing (115200 baud)${NC}"

# Run simulation
xsim tb_cross_system_with_adapters_sim -runall

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Simulation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}========================================${NC}"

# Check for VCD file
if [ -f "tb_cross_system_with_adapters.vcd" ]; then
    echo -e "${GREEN}SUCCESS: Simulation completed!${NC}"
    echo -e "${GREEN}VCD waveform file: tb_cross_system_with_adapters.vcd${NC}"
    echo -e "${YELLOW}View waveforms: gtkwave tb_cross_system_with_adapters.vcd${NC}"
else
    echo -e "${RED}WARNING: VCD file not generated${NC}"
fi

echo -e "${YELLOW}========================================${NC}"

exit 0
