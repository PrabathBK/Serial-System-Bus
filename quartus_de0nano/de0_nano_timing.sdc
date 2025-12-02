#==============================================================================
# Timing Constraints for ADS Bus System Demo on DE0-Nano
# Target: Terasic DE0-Nano (Cyclone IV EP4CE22F17C6N)
# Clock: 50 MHz
# Date: 2025-12-02
#==============================================================================

#==============================================================================
# Clock Definition
#==============================================================================
create_clock -name "CLOCK_50" -period 20.000 [get_ports {CLOCK_50}]

#==============================================================================
# Clock Uncertainty
#==============================================================================
derive_clock_uncertainty

#==============================================================================
# Input Delays
#==============================================================================
# Asynchronous inputs (buttons, switches)
set_false_path -from [get_ports {KEY[*]}] -to *
set_false_path -from [get_ports {SW[*]}] -to *

# UART RX inputs (asynchronous)
set_false_path -from [get_ports {GPIO_0_BRIDGE_M_RX}] -to *
set_false_path -from [get_ports {GPIO_0_BRIDGE_S_RX}] -to *

#==============================================================================
# Output Delays
#==============================================================================
# LED outputs (no timing critical)
set_false_path -from * -to [get_ports {LED[*]}]

# UART TX outputs
set_false_path -from * -to [get_ports {GPIO_0_BRIDGE_M_TX}]
set_false_path -from * -to [get_ports {GPIO_0_BRIDGE_S_TX}]
