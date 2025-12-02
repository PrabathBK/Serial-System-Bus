#**************************************************************
# ADS Bus System Demo - Timing Constraints
# Target: Terasic DE0-Nano (Intel Cyclone IV EP4CE22F17C6)
# Clock: 50 MHz from on-board oscillator
# Date: December 2, 2025
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
# 50 MHz clock from DE0-Nano board (period = 20 ns)
create_clock -name {CLOCK_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLOCK_50}]

#**************************************************************
# Create Generated Clock
#**************************************************************
# No PLLs or generated clocks in this design

#**************************************************************
# Set Clock Latency
#**************************************************************
# Account for clock routing delays
set_clock_latency -source -early 0.100 [get_clocks {CLOCK_50}]
set_clock_latency -source -late 0.200 [get_clocks {CLOCK_50}]

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
# Account for jitter and other uncertainties
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************
# Push buttons - asynchronous inputs, no timing constraint needed
set_false_path -from [get_ports {KEY[*]}]

# DIP switches - asynchronous inputs (directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly directly used for reset and config)
set_false_path -from [get_ports {SW[*]}]

#**************************************************************
# Set Output Delay
#**************************************************************
# LEDs are outputs with relaxed timing - set as false path
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

# Button synchronizers - first two stages can be metastable
set_false_path -to [get_registers {*key0_sync[0]*}]
set_false_path -to [get_registers {*key1_sync[0]*}]

# Switch synchronizers - first stage can be metastable
set_false_path -to [get_registers {*sw_sync1[*]}]

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
# Performance Goals
#**************************************************************
# Goal: Achieve at least 50 MHz operation (20ns period)
# With optimization, should easily achieve 100 MHz+
# The design is simple shift-register based serial protocol
