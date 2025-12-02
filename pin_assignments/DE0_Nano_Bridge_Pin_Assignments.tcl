# ADS Bus System Demo with Bus Bridge - DE0-Nano Pin Assignments
# Target: Terasic DE0-Nano (Intel Cyclone IV EP4CE22F17C6)
# Date: December 2, 2025

#============================================================
# CLOCK
#============================================================
set_location_assignment PIN_R8 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

#============================================================
# PUSH BUTTONS (Active Low)
#============================================================
set_location_assignment PIN_J15 -to KEY[0]
set_location_assignment PIN_E1 -to KEY[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[1]

#============================================================
# DIP SWITCHES
#============================================================
set_location_assignment PIN_M1 -to SW[0]
set_location_assignment PIN_T8 -to SW[1]
set_location_assignment PIN_B9 -to SW[2]
set_location_assignment PIN_M15 -to SW[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[3]

#============================================================
# LEDs
#============================================================
set_location_assignment PIN_A15 -to LED[0]
set_location_assignment PIN_A13 -to LED[1]
set_location_assignment PIN_B13 -to LED[2]
set_location_assignment PIN_A11 -to LED[3]
set_location_assignment PIN_D1 -to LED[4]
set_location_assignment PIN_F3 -to LED[5]
set_location_assignment PIN_B1 -to LED[6]
set_location_assignment PIN_L3 -to LED[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[7]

#============================================================
# GPIO - Bus Bridge UART Interface (directly directly directly directly directly directly directly directly directly directly GPIO_0 Header)
#============================================================
# Bridge Master UART (Master 2)
set_location_assignment PIN_A8 -to GPIO_0_BRIDGE_M_TX
set_location_assignment PIN_D3 -to GPIO_0_BRIDGE_M_RX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to GPIO_0_BRIDGE_M_TX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to GPIO_0_BRIDGE_M_RX

# Bridge Slave UART (Slave 3)
set_location_assignment PIN_B8 -to GPIO_0_BRIDGE_S_TX
set_location_assignment PIN_C3 -to GPIO_0_BRIDGE_S_RX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to GPIO_0_BRIDGE_S_TX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to GPIO_0_BRIDGE_S_RX
