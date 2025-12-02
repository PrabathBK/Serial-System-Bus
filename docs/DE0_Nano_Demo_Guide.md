# ADS Bus System - DE0-Nano Demonstration Guide

## Overview

This guide explains how to demonstrate the ADS Serial Bus System on the DE0-Nano FPGA board, including:
1. **Internal Communication** - Master writing/reading to internal slaves
2. **External Communication** - Master communicating via Bus Bridge (UART) to another FPGA

---

## Hardware Setup

### DE0-Nano Board Resources

| Resource | Pin | Usage |
|----------|-----|-------|
| CLOCK_50 | PIN_R8 | 50 MHz system clock |
| KEY[0] | PIN_J15 | Reset (active low - press to reset) |
| KEY[1] | PIN_E1 | Execute transaction (press and release) |
| SW[3:2] | PIN_M15, PIN_B9 | Mode select (see table below) |
| SW[1:0] | PIN_T8, PIN_M1 | Data input (lower 2 bits) |
| LED[7:0] | Various | Data/status display |

### Mode Selection (SW[3:2])

| SW[3] | SW[2] | Mode | Target |
|-------|-------|------|--------|
| 0 | 0 | Write | Slave 1 (Internal 2KB memory) |
| 0 | 1 | Write | Slave 2 (Internal 4KB memory) |
| 1 | 0 | Write | Slave 3 (Bus Bridge → External) |
| 1 | 1 | Read | From last written slave |

### GPIO Connections for Bus Bridge

| Signal | DE0-Nano Pin | Direction | Description |
|--------|--------------|-----------|-------------|
| GPIO_0_BRIDGE_M_RX | PIN_A8 (GPIO_0[0]) | Input | Bridge Master receives from external |
| GPIO_0_BRIDGE_M_TX | PIN_D3 (GPIO_0[1]) | Output | Bridge Master sends to external |
| GPIO_0_BRIDGE_S_RX | PIN_B8 (GPIO_0[2]) | Input | Bridge Slave receives from external |
| GPIO_0_BRIDGE_S_TX | PIN_C3 (GPIO_0[3]) | Output | Bridge Slave sends to external |

---

## Test 1: Internal Communication (Single Board)

This test demonstrates Master 1 writing and reading from internal Slave 1 and Slave 2.

### Steps:

1. **Program the FPGA**
   ```bash
   # Open Quartus, compile and program de0_nano_demo.sof
   quartus_pgm -m jtag -o "p;output_files/de0_nano_demo.sof"
   ```

2. **Reset the System**
   - Press and hold **KEY[0]** for 1 second, then release
   - All LEDs should turn OFF (reset state)

3. **Write to Slave 1**
   - Set **SW[3:2] = 00** (Slave 1 write mode)
   - Set **SW[1:0]** to any value (e.g., 01 for data pattern)
   - Press and release **KEY[1]** to execute write
   - LEDs will show busy animation, then pattern `10101010` on success

4. **Read from Slave 1**
   - Set **SW[3:2] = 11** (Read mode)
   - Press and release **KEY[1]** to execute read
   - LEDs will display the data read from memory
   - Expected: Data pattern based on `{counter[5:0], SW[1:0]}`

5. **Write to Slave 2**
   - Set **SW[3:2] = 01** (Slave 2 write mode)
   - Set **SW[1:0]** to a different value (e.g., 10)
   - Press and release **KEY[1]** to execute write

6. **Read from Slave 2**
   - Set **SW[3:2] = 11** (Read mode - reads from last written slave)
   - Press and release **KEY[1]** to execute read
   - LEDs show data from Slave 2

### Expected LED Behavior:

| State | LED Pattern | Meaning |
|-------|-------------|---------|
| Idle (Write mode) | `00_SS_DD_CC` | SS=slave select, DD=data preview, CC=counter |
| Idle (Read mode) | `XXXXXXXX` | Last read data (8 bits) |
| Busy | Animated | Transaction in progress |
| Write Done | `10101010` | Write completed successfully |
| Read Done | Data value | Shows the read data |

---

## Test 2: External Communication (Two Boards via UART Bridge)

This test demonstrates cross-system communication using the Bus Bridge.

### Hardware Connection (Two DE0-Nano Boards)

```
    Board A (System A)                    Board B (System B)
    ==================                    ==================
    
    GPIO_0_BRIDGE_S_TX (PIN_C3) -------> GPIO_0_BRIDGE_M_RX (PIN_A8)
    GPIO_0_BRIDGE_S_RX (PIN_B8) <------- GPIO_0_BRIDGE_M_TX (PIN_D3)
    
    GPIO_0_BRIDGE_M_TX (PIN_D3) -------> GPIO_0_BRIDGE_S_RX (PIN_B8)
    GPIO_0_BRIDGE_M_RX (PIN_A8) <------- GPIO_0_BRIDGE_S_TX (PIN_C3)
    
    GND -------------------------------- GND
```

### Wiring Diagram:

```
Board A                                          Board B
┌─────────────────┐                    ┌─────────────────┐
│   DE0-Nano      │                    │   DE0-Nano      │
│                 │                    │                 │
│  Bridge Slave   │                    │  Bridge Master  │
│  TX (PIN_C3) ───┼────────────────────┼─> RX (PIN_A8)   │
│  RX (PIN_B8) <──┼────────────────────┼── TX (PIN_D3)   │
│                 │                    │                 │
│  Bridge Master  │                    │  Bridge Slave   │
│  TX (PIN_D3) ───┼────────────────────┼─> RX (PIN_B8)   │
│  RX (PIN_A8) <──┼────────────────────┼── TX (PIN_C3)   │
│                 │                    │                 │
│      GND ───────┼────────────────────┼── GND           │
└─────────────────┘                    └─────────────────┘
```

### Steps:

1. **Program Both FPGAs**
   - Program the same `de0_nano_demo.sof` to both boards
   - Both boards run identical firmware

2. **Connect UART Lines**
   - Use jumper wires to connect GPIO pins as shown above
   - **IMPORTANT:** Connect GND between boards!

3. **Reset Both Systems**
   - Press KEY[0] on both boards

4. **Board A: Write to External (Board B's Slave)**
   - On Board A: Set **SW[3:2] = 10** (Write to Bridge Slave)
   - Set **SW[1:0]** to desired data pattern
   - Press **KEY[1]** to execute
   
   **What happens:**
   - Board A's Master 1 writes to its Slave 3 (Bridge Slave)
   - Bridge Slave sends UART packet to Board B
   - Board B's Bridge Master receives and writes to Board B's Slave 1

5. **Board B: Verify Data Received**
   - On Board B: Set **SW[3:2] = 11** (Read mode)
   - Press **KEY[1]** to read from internal slave
   - LEDs should show the data sent from Board A

6. **Board B: Write Back to Board A**
   - On Board B: Set **SW[3:2] = 10** (Write to Bridge)
   - Press **KEY[1]**
   - On Board A: Read to verify (SW[3:2] = 11)

---

## Test 3: Using USB-UART Adapter (PC to FPGA)

You can also test the bridge using a USB-UART adapter connected to a PC.

### Hardware Setup:

```
PC (USB-UART)                    DE0-Nano
=============                    ========
TX  ─────────────────────────>  GPIO_0_BRIDGE_M_RX (PIN_A8)
RX  <─────────────────────────  GPIO_0_BRIDGE_M_TX (PIN_D3)
GND ─────────────────────────── GND
```

### UART Settings:
- Baud Rate: **9600 bps**
- Data Bits: 8
- Stop Bits: 1
- Parity: None

### UART Packet Format (from PC to FPGA):

The Bridge Master expects packets in this format:
```
Bit Position: [20]    [19:12]    [11:0]
              MODE    DATA       ADDRESS
              
MODE: 1 = Write, 0 = Read
DATA: 8-bit data to write (ignored for read)
ADDRESS: 12-bit memory address
```

### Python Test Script:

```python
#!/usr/bin/env python3
"""
ADS Bus Bridge UART Test Script
Sends commands to DE0-Nano via USB-UART adapter
"""

import serial
import time

# Configure serial port
PORT = '/dev/ttyUSB0'  # Change to your port (COM3 on Windows)
BAUD = 9600

def send_packet(ser, mode, data, addr):
    """
    Send a 21-bit packet (3 bytes) to the bus bridge
    Format: {mode[1], data[8], addr[12]} = 21 bits -> 3 bytes
    """
    # Pack into 3 bytes (LSB first)
    packet = (mode << 20) | (data << 12) | addr
    byte0 = packet & 0xFF
    byte1 = (packet >> 8) & 0xFF
    byte2 = (packet >> 16) & 0xFF
    
    ser.write(bytes([byte0, byte1, byte2]))
    print(f"Sent: mode={mode}, data=0x{data:02X}, addr=0x{addr:03X}")
    print(f"  Bytes: [{byte0:02X}, {byte1:02X}, {byte2:02X}]")

def main():
    ser = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(0.1)
    
    print("=== ADS Bus Bridge Test ===")
    
    # Test 1: Write 0xAB to address 0x010 (Slave 1)
    print("\nTest 1: Write to Slave 1")
    send_packet(ser, mode=1, data=0xAB, addr=0x010)
    time.sleep(0.5)
    
    # Test 2: Write 0xCD to address 0x100 (Slave 1)
    print("\nTest 2: Write to Slave 1 different address")
    send_packet(ser, mode=1, data=0xCD, addr=0x100)
    time.sleep(0.5)
    
    # Test 3: Read from address 0x010
    print("\nTest 3: Read from Slave 1")
    send_packet(ser, mode=0, data=0x00, addr=0x010)
    time.sleep(0.5)
    
    # Wait for response (if bridge master sends read data back)
    response = ser.read(10)
    if response:
        print(f"Response: {response.hex()}")
    
    ser.close()
    print("\nDone!")

if __name__ == "__main__":
    main()
```

---

## LED Status Reference

### During Idle:
- **Write mode (SW[3:2] = 00, 01, 10):** Shows preview of target and data
- **Read mode (SW[3:2] = 11):** Shows last read value

### During Transaction:
- **Animated pattern:** Blinking indicates bus activity
- **LED[4]:** Master bus grant
- **LED[3]:** Master acknowledge
- **LED[1:0]:** Slave ready status

### After Transaction:
- **0xAA (10101010):** Write completed successfully
- **Data value:** Read completed, showing read data

---

## Troubleshooting

### Issue: LEDs don't respond to button press
- Check reset: Press KEY[0] first
- Ensure FPGA is programmed correctly
- Verify clock source (50 MHz)

### Issue: Read returns wrong data
- Ensure you wrote to the correct slave first
- Check SW[3:2] mode setting
- Try resetting and starting fresh

### Issue: Bridge communication fails
- Verify wiring: TX→RX, RX→TX, GND→GND
- Check UART baud rate (9600 bps)
- Ensure both boards are powered and programmed
- Use oscilloscope to verify UART signals

### Issue: Timeout during transaction
- Transaction takes too long (>1ms timeout)
- Check for bus conflicts
- Reset both systems

---

## Memory Map Reference

| Slave | Device Address | Memory Address Range | Size |
|-------|----------------|---------------------|------|
| Slave 1 | 0x0xxx | 0x000 - 0x7FF | 2KB |
| Slave 2 | 0x1xxx | 0x000 - 0xFFF | 4KB |
| Slave 3 (Bridge) | 0x2xxx | N/A (forwards via UART) | - |

---

## Quick Test Checklist

### Internal Test (Single Board):
- [ ] Program FPGA
- [ ] Reset (KEY[0])
- [ ] Write to Slave 1 (SW=00, then KEY[1])
- [ ] Read from Slave 1 (SW=11, then KEY[1])
- [ ] Verify LED shows written data
- [ ] Repeat for Slave 2 (SW=01)

### External Test (Two Boards):
- [ ] Program both FPGAs
- [ ] Connect UART wires (TX↔RX cross-connected)
- [ ] Connect GND
- [ ] Reset both boards
- [ ] Board A: Write to bridge (SW=10)
- [ ] Board B: Read internal slave (SW=11)
- [ ] Verify data matches

---

## File Structure

```
quartus_de0nano/
├── de0_nano_demo.qpf          # Quartus project file
├── de0_nano_demo.qsf          # Project settings and source files
├── de0_nano_pins.qsf          # Pin assignments
├── de0_nano_timing.sdc        # Timing constraints
└── output_files/
    └── de0_nano_demo.sof      # Programming file (after compilation)

rtl/
├── de0_nano_demo_top.v        # Top-level demo module
└── core/
    ├── bus_m2_s3.v            # Bus interconnect
    ├── master_port.v          # Master port
    ├── slave.v                # Slave wrapper
    ├── bus_bridge_master.v    # UART bridge master
    ├── bus_bridge_slave.v     # UART bridge slave
    └── ...                    # Other core modules
```

---

## Compilation Steps

```bash
cd quartus_de0nano

# Option 1: Command line
quartus_sh --flow compile de0_nano_demo

# Option 2: GUI
quartus de0_nano_demo.qpf
# Then: Processing → Start Compilation

# Program the device
quartus_pgm -m jtag -o "p;output_files/de0_nano_demo.sof"
```
