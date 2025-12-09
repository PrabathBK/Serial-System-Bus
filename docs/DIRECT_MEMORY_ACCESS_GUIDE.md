# Direct Memory Access Guide - Reading/Writing Other Team's FPGA

This guide explains how to directly read from and write to the other team's FPGA memory using your DE0-Nano setup.

## Table of Contents
1. [Hardware Connections](#hardware-connections)
2. [System Configuration](#system-configuration)
3. [How to WRITE Data](#how-to-write-data)
4. [How to READ Data](#how-to-read-data)
5. [Their Memory Map](#their-memory-map)
6. [Address Limitations](#address-limitations)
7. [Troubleshooting](#troubleshooting)

---

## Hardware Connections

### Physical Wiring (GPIO_0 Pins)

**Scenario: YOU Initiate Transactions** (You send commands to their system)

```
Your DE0-Nano                  Their DE0-Nano
GPIO Pin         Direction     GPIO Pin                    Purpose
================================================================================
GPIO_0[2]  (TX)  --------->    bridge_target_uart_rx       Your commands OUT
GPIO_0[3]  (RX)  <---------    bridge_target_uart_tx       Their responses IN
GND              <-------->    GND                         Common ground (CRITICAL!)
```

**Pin Mapping:**
- `GPIO_0_BRIDGE_S_TX` = GPIO_0[2] on your FPGA
- `GPIO_0_BRIDGE_S_RX` = GPIO_0[3] on your FPGA
- Connect to their `bridge_target_uart_rx` and `bridge_target_uart_tx`

### Important Notes:
- **ALWAYS connect GND between both FPGAs** - Without common ground, communication will fail
- **TX connects to RX** - Transmit from one connects to Receive on other
- **115200 baud** - Both systems must use same baud rate (already configured)
- **Protocol adapters MUST be enabled** - Set `ENABLE_ADAPTERS = 1` in your code

---

## System Configuration

### 1. Enable Adapters in Your Code

Edit `rtl/demo_uart_bridge.v` line 66:

```verilog
// BEFORE (default - won't work with other team):
parameter ENABLE_ADAPTERS = 0

// AFTER (required for other team):
parameter ENABLE_ADAPTERS = 1
```

### 2. Verify Baud Rate

Already configured at line 114 in `demo_uart_bridge.v`:
```verilog
localparam UART_CLOCKS_PER_PULSE = 434;  // 50MHz / 115200 = 434
```

### 3. Program Your FPGA

```bash
cd quartus/
quartus_pgm -m jtag -o "p;output_files/ads_bus_system.sof@1"
```

### 4. Coordinate with Other Team

Ask them to:
1. Program their FPGA with `system_top_with_bus_bridge_symmetric.sv`
2. Confirm they're using **115200 baud**
3. Confirm pin connections match their design
4. Tell you which addresses to target (must be in range 0x0000-0x0FFF)

---

## How to WRITE Data

### Step-by-Step Procedure

#### 1. **Power On & Reset**
- Ensure both FPGAs are powered
- Set `SW[0] = 0` (LOW) on your FPGA to release reset

#### 2. **Configure Switches for WRITE mode**

```
SW[3] = 1    ← WRITE mode
SW[2] = 1    ← EXTERNAL mode (use bridge to other FPGA)
SW[1] = 0    ← Target their Slave 1 (addresses 0x0000-0x07FF)
      = 1    ← Target their Slave 2 (addresses 0x4000+, but OUT OF YOUR RANGE!)
SW[0] = 0    ← Reset OFF
```

**Result:** LEDs will show current data value

#### 3. **Set Data Value to Write**

Press `KEY[1]` repeatedly to increment the data value:
- Each press increments by 1
- LEDs show the current value in binary
- Example: Press 10 times → LEDs show `0b00001010` (0x0A)

#### 4. **Execute the Write**

Press `KEY[0]` to send the write command:
- Your FPGA will:
  1. Package data as 21-bit frame: `{write=1, addr[11:0], data[7:0]}`
  2. TX adapter converts to 4-byte sequence:
     - Byte 0: addr[7:0]
     - Byte 1: addr[15:8] (upper 4 bits = 0)
     - Byte 2: data[7:0]
     - Byte 3: 0x01 (write flag)
  3. Send via UART at 115200 baud to their `bridge_target_uart_rx`
  4. Wait for their ACK response (2-byte sequence)
  5. Address auto-increments for next write

#### 5. **Sequential Writes**

To write multiple bytes:
1. Press `KEY[1]` to set next data value
2. Press `KEY[0]` to write (address auto-increments)
3. Repeat

**Reset counters:** Press both `KEY[0] + KEY[1]` together to reset address and data to 0

---

## How to READ Data

### Step-by-Step Procedure

#### 1. **Configure Switches for READ mode**

```
SW[3] = 0    ← READ mode
SW[2] = 1    ← EXTERNAL mode (use bridge)
SW[1] = 0    ← Target their Slave 1 (0x0000-0x07FF)
SW[0] = 0    ← Reset OFF
```

**Result:** LEDs will show data read from their memory

#### 2. **Set Address to Read**

Press `KEY[1]` repeatedly to select address:
- Each press increments address offset by 1
- Base address is 0x010 (defined in code line 110)
- Address = 0x010 + offset
- Example: Press 5 times → Address = 0x015

#### 3. **Execute the Read**

Press `KEY[0]` to send the read command:
- Your FPGA will:
  1. Package read request as 21-bit frame: `{read=0, addr[11:0], data=0x00}`
  2. TX adapter converts to 4-byte sequence:
     - Byte 0: addr[7:0]
     - Byte 1: addr[15:8]
     - Byte 2: 0x00 (data unused for read)
     - Byte 3: 0x00 (read flag)
  3. Send via UART to their system
  4. Wait for their 2-byte response:
     - Byte 0: data[7:0]
     - Byte 1: flags (ignored)
  5. RX adapter extracts data byte
  6. Display on LEDs

#### 4. **Read Different Addresses**

To read from other addresses:
1. Press `KEY[1]` to increment address
2. Press `KEY[0]` to read from new address
3. LEDs show the received data

---

## Their Memory Map

### System Architecture (from `system_top_with_bus_bridge_symmetric.sv`)

```
Address Range      Size    Module              Accessible from Your System?
================================================================================
0x0000 - 0x07FF    2KB     Target 0 (BRAM)     ✓ YES (within 12-bit range)
0x4000 - 0x4FFF    4KB     Target 1 (BRAM)     ✗ NO  (requires bit 14 = 1)
0x8000 - 0x8FFF    4KB     Bridge (target)     ✗ NO  (requires bit 15 = 1)
0x9000 - 0x9FFF    4KB     Bridge (remote)     ✗ NO  (out of range)
```

### What You Can Access

**Target 0 Only:** Addresses **0x0000 to 0x07FF** (2KB)

Their Target 0 configuration (lines 43-44 in their code):
```verilog
parameter TARGET0_BASE_ADDR = 16'h0000;
parameter TARGET0_SIZE      = 2048;  // 2KB
```

### What You CANNOT Access

Due to your 12-bit address limitation:
- **Target 1** at 0x4000+ (requires bit 14, you only have bits [11:0])
- **Bridge** at 0x8000+ (requires bit 15)
- Any address > 0x0FFF

---

## Address Limitations

### Your System
- **Address width:** 12 bits
- **Address range:** 0x000 - 0xFFF (4KB)
- **Bits used:** [11:0]

### Their System
- **Address width:** 16 bits
- **Address range:** 0x0000 - 0xFFFF (64KB)
- **Bits used:** [15:0]

### Compatibility

When you send 12-bit addresses, they get padded to 16 bits:
```
Your address:  0xABC (12 bits: 0000 1010 1011 1100)
Sent as:       0x0ABC (16 bits: 0000 0000 1010 1011 1100)
```

**Upper 4 bits are always 0**, limiting you to addresses 0x0000-0x0FFF.

### Workarounds

If you need to access higher addresses:

**Option A:** Modify their address decoder to map your range
- Ask them to alias higher memory to lower addresses

**Option B:** Extend your address width
- Modify `BB_ADDR_WIDTH` from 12 to 16 in your code
- Update `demo_uart_bridge.v`, `bus_bridge_slave.v`, `bus_bridge_master.v`
- Resynthesize and reprogram

**Option C:** Use their button-triggered initiator
- They press button → sends to your system
- You respond to their requests

---

## Troubleshooting

### No Response from Other Team's FPGA

**Check:**
1. ✓ GND connected between FPGAs
2. ✓ TX/RX properly crossed (your TX → their RX)
3. ✓ Both FPGAs programmed and powered
4. ✓ `ENABLE_ADAPTERS = 1` in your code
5. ✓ Both using 115200 baud
6. ✓ Their system is listening on correct UART pair
7. ✓ Address in valid range (0x0000-0x07FF for Target 0)

### Incorrect Data Received

**Check:**
1. ✓ Address mapping: Are you hitting the right memory?
2. ✓ Protocol timing: Wait for full response before next command
3. ✓ View waveforms: Use simulator to verify protocol sequence

**Debug with simulator:**
```bash
./sim/run_uart_adapter_test.sh
gtkwave sim/tb_uart_adapters.vcd
```

### Timeout Errors

**Possible causes:**
1. Their system not responding (check their FPGA status)
2. UART baud rate mismatch (verify both use 434 CLOCKS_PER_PULSE)
3. Adapter not converting correctly (check adapter test passes)
4. Address out of range (use only 0x0000-0x07FF)

**Increase timeout:**
Edit `demo_uart_bridge.v` line 419:
```verilog
// BEFORE:
if (m1_dready || (demo_counter > 20'd500000)) begin

// AFTER (longer timeout):
if (m1_dready || (demo_counter > 20'd1000000)) begin
```

### Address Auto-Increment Issues

**Reset address and data:**
- Press both `KEY[0] + KEY[1]` together
- Both counters reset to 0

**Check base address:**
Line 110 in `demo_uart_bridge.v`:
```verilog
localparam [11:0] BASE_MEM_ADDR = 12'h010;  // Starts at 0x010
```

---

## Quick Reference Card

### Your Switch Settings

| Task | SW[3] | SW[2] | SW[1] | SW[0] |
|------|-------|-------|-------|-------|
| **Write to their Target 0** | 1 | 1 | 0 | 0 |
| **Read from their Target 0** | 0 | 1 | 0 | 0 |
| **Write to local Slave 1** | 1 | 0 | 0 | 0 |
| **Read from local Slave 1** | 0 | 0 | 0 | 0 |
| **Reset system** | X | X | X | 1 |

### Button Functions

| Button | Write Mode | Read Mode | Both Together |
|--------|------------|-----------|---------------|
| **KEY[0]** | Execute write | Execute read | Reset counters |
| **KEY[1]** | Increment data | Increment addr | Reset counters |

### LED Display

| Mode | LED[7:0] Shows |
|------|----------------|
| **Write (SW[3]=1)** | Current data value to write |
| **Read (SW[3]=0)** | Last data read from memory |

---

## Example Session

### Writing 0xAB to Address 0x010 on Their Target 0

```
1. Set switches: SW = 0b1100 (WRITE, EXTERNAL, Target0, No Reset)
2. Press KEY[1] 171 times to get 0xAB on LEDs
3. Press KEY[0] to send write
4. Wait ~10ms for ACK
5. Done! Their address 0x010 now contains 0xAB
```

### Reading from Address 0x015 on Their Target 0

```
1. Set switches: SW = 0b0100 (READ, EXTERNAL, Target0, No Reset)
2. Press KEY[1] 5 times (addr offset = 5 → 0x010 + 5 = 0x015)
3. Press KEY[0] to send read
4. Wait for response
5. LEDs show data read from their address 0x015
```

---

## Protocol Details (For Debugging)

### Your 21-bit Frame Format
```
Bit 20:    Mode (1=Write, 0=Read)
Bits 19:8: Address [11:0]
Bits 7:0:  Data [7:0]
```

### 4-Byte Sequence to Their System (via TX Adapter)
```
Byte 0: addr[7:0]       (Address LSB)
Byte 1: addr[15:8]      (Address MSB, upper 4 bits = 0)
Byte 2: data[7:0]       (Write data)
Byte 3: {7'b0, mode}    (Write flag in bit 0)
```

### 2-Byte Response from Their System (via RX Adapter)
```
Byte 0: data[7:0]       (Read data or write ACK)
Byte 1: {7'b0, flag}    (Status flags)
```

---

## References

- **Your top module:** `rtl/demo_uart_bridge.v`
- **TX adapter:** `rtl/core/uart_to_other_team_tx_adapter.v`
- **RX adapter:** `rtl/core/uart_to_other_team_rx_adapter.v`
- **Bridge slave:** `rtl/core/bus_bridge_slave.v` (sends commands)
- **Bridge master:** `rtl/core/bus_bridge_master.v` (receives responses)
- **Their top module:** `Quartus_other_team/system_top_with_bus_bridge_symmetric.sv`
- **Integration status:** `CROSS_SYSTEM_INTEGRATION_STATUS.md`
- **Compatibility analysis:** `SYMMETRIC_MODULE_COMPATIBILITY_ANALYSIS.md`
