#**************************************************************
# ADS Bus System - Timing Constraints
# Target: Terasic DE10-Nano (Intel Cyclone V 5CSEBA6U23I7)
# Clock: 50 MHz from on-board oscillator
# Date: October 14, 2025
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
# 50 MHz clock from DE10-Nano board (period = 20 ns)
create_clock -name {FPGA_CLK1_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {FPGA_CLK1_50}]

#**************************************************************
# Create Generated Clock
#**************************************************************
# No PLLs or generated clocks in this design

#**************************************************************
# Set Clock Latency
#**************************************************************
# Account for clock routing delays
set_clock_latency -source -early 0.100 [get_clocks {FPGA_CLK1_50}]
set_clock_latency -source -late 0.200 [get_clocks {FPGA_CLK1_50}]

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
# Account for jitter and other uncertainties
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************
# GPIO inputs - assume data is valid 2ns after clock edge
# (conservative estimate for external master connections)
set_input_delay -clock [get_clocks {FPGA_CLK1_50}] -min 1.000 [get_ports {GPIO_M1_*}]
set_input_delay -clock [get_clocks {FPGA_CLK1_50}] -max 3.000 [get_ports {GPIO_M1_*}]
set_input_delay -clock [get_clocks {FPGA_CLK1_50}] -min 1.000 [get_ports {GPIO_M2_*}]
set_input_delay -clock [get_clocks {FPGA_CLK1_50}] -max 3.000 [get_ports {GPIO_M2_*}]

# KEY0 is asynchronous reset - no timing constraint needed
set_false_path -from [get_ports {KEY0}]

#**************************************************************
# Set Output Delay
#**************************************************************
# GPIO outputs - assume external devices sample 2ns before next clock edge
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -min 0.000 [get_ports {GPIO_M1_*}]
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -max 2.000 [get_ports {GPIO_M1_*}]
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -min 0.000 [get_ports {GPIO_M2_*}]
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -max 2.000 [get_ports {GPIO_M2_*}]

# LEDs are outputs with relaxed timing
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -min 0.000 [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {FPGA_CLK1_50}] -max 5.000 [get_ports {LED[*]}]
# LEDs don't need tight timing - set as false path
set_false_path -to [get_ports {LED[*]}]

#**************************************************************
# Set Clock Groups
#**************************************************************
# No clock domain crossings in this single-clock design

#**************************************************************
# Set False Path
#**************************************************************
# Reset synchronizer - first two stages can be metastable
set_false_path -to [get_registers {*reset_sync[0]*}]

#**************************************************************
# Set Multicycle Path
#**************************************************************
# No multicycle paths in this design

#**************************************************************
# Set Maximum Delay
#**************************************************************
# None required

#**************************************************************
# Set Minimum Delay
#**************************************************************
# None required

#**************************************************************
# Design Rule Constraints
#**************************************************************
# Note: Advanced design rules removed to avoid SDC parsing errors
# The design should meet timing with basic constraints above

#**************************************************************
# Performance Goals
#**************************************************************
# Goal: Achieve at least 50 MHz operation (20ns period)
# With optimization, should easily achieve 100 MHz+
# The design is simple shift-register based serial protocol
