# UART Bridge Compatibility Analysis

## Executive Summary
**INCOMPATIBLE** - The two systems use fundamentally different UART protocols and frame formats. Modifications are required to enable communication.

---

## System A: Your System (ADS Serial Bus)

### UART Physical Layer
- **Baud Rate**: 9600 bps (configurable via `UART_CLOCKS_PER_PULSE = 5208`)
- **Format**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Implementation**: Custom UART with cycle-based timing
- **Clock**: 50 MHz

### Protocol Layer - Bus Bridge

#### Bridge Master (Receives commands from external)
- **RX Frame**: 21 bits total sent as single frame
  - `UART_RX_DATA_WIDTH = DATA_WIDTH + BB_ADDR_WIDTH + 1`
  - `= 8 + 12 + 1 = 21 bits`
- **TX Frame**: 8 bits (read response data only)
  - `UART_TX_DATA_WIDTH = DATA_WIDTH = 8 bits`

#### Bridge Slave (Sends commands to external)
- **TX Frame**: 21 bits total sent as single frame
  - `UART_TX_DATA_WIDTH = DATA_WIDTH + ADDR_WIDTH + 1`
  - `= 8 + 12 + 1 = 21 bits`
- **RX Frame**: 8 bits (read response data only)
  - `UART_RX_DATA_WIDTH = DATA_WIDTH = 8 bits`

**Key Point**: Your system sends/receives the entire transaction (mode + address + data) as a **single wide UART frame**.

---

## System B: Other Team's System

### UART Physical Layer
- **Baud Rate**: 115200 bps (hardcoded in baudrate.v)
- **Format**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Implementation**: Clock enable-based UART with oversampling (16x for RX)
- **Clock**: 50 MHz

### Protocol Layer - Bus Bridge

#### Initiator (their equivalent of Bridge Master)
- **RX Frame**: 4-byte sequence (32 bits total)
  - Byte 0: Address[7:0] (LSB)
  - Byte 1: Address[15:8] (MSB)
  - Byte 2: Write Data[7:0]
  - Byte 3: Flags (bit 0 = is_write)
- **TX Frame**: 2-byte sequence (16 bits total)
  - Byte 0: Read Data[7:0]
  - Byte 1: Flags (bit 0 = is_write)

#### Target (their equivalent of Bridge Slave)
- **TX Frame**: 4-byte sequence (32 bits total)
  - Byte 0: Address[7:0] (LSB)
  - Byte 1: Address[15:8] (MSB)
  - Byte 2: Write Data[7:0]
  - Byte 3: Flags (bit 0 = is_write)
- **RX Frame**: 2-byte sequence (16 bits total)
  - Byte 0: Read Data[7:0]
  - Byte 1: Flags (bit 0 = is_write)

**Key Point**: Their system sends/receives the transaction as a **multi-byte sequence** (4 separate 8-bit UART frames for commands, 2 for responses).

---

## Critical Incompatibilities

### 1. Frame Structure (CRITICAL)
| Aspect | Your System | Their System | Compatible? |
|--------|-------------|--------------|-------------|
| Frame width | 21-bit single frame | 4x 8-bit frames | ❌ NO |
| Byte ordering | N/A (single frame) | LSB-first for address | ❌ NO |
| Sequencing | All-at-once | Sequential bytes | ❌ NO |

### 2. Baud Rate (CRITICAL)
| Parameter | Your System | Their System | Compatible? |
|-----------|-------------|--------------|-------------|
| Baud rate | 9600 bps | 115200 bps | ❌ NO |
| Clock divider | 5208 cycles/bit | 434 cycles/bit | ❌ NO |

### 3. Address Width
| Parameter | Your System | Their System | Compatible? |
|-----------|-------------|--------------|-------------|
| Address width | 12 bits | 16 bits | ⚠️ PARTIAL |

### 4. Control Interface
| Parameter | Your System | Their System | Compatible? |
|-----------|-------------|--------------|-------------|
| Ready signal | `ready` (single pulse) | `ready` + `ready_clr` | ⚠️ DIFFERENT |
| Enable signal | `data_en` | `wr_en` | ✅ YES |

---

## Required Modifications

### Option 1: Adapter Module (Recommended)
Create protocol adapter modules that sit between your UART and their UART:

**Your System Changes:**
1. Keep existing UART at 9600 bps
2. Add `uart_protocol_adapter` module to:
   - Convert 21-bit frames to 4-byte sequences
   - Convert 4-byte sequences to 21-bit frames
   - Handle byte-by-byte transmission/reception
   - Synchronize with their ready/ready_clr handshaking

**Advantage**: No changes to core bus bridge logic.

### Option 2: Modify Your UART (More Invasive)
1. Change baud rate to 115200 bps (`UART_CLOCKS_PER_PULSE = 434`)
2. Rewrite bus bridge master/slave to send/receive multi-byte sequences
3. Add FSM to handle 4-byte TX and 2-byte RX for master
4. Add FSM to handle 4-byte RX and 2-byte TX for slave

**Disadvantage**: Requires extensive changes to bus_bridge_master.v and bus_bridge_slave.v

### Option 3: Modify Their System
1. Ask them to change baud rate to 9600 bps
2. Ask them to support 21-bit frames

**Disadvantage**: Requires coordination and their team's work.

---

## Recommended Solution: Protocol Adapter

Create two new adapter modules:

### Module 1: `uart_frame_adapter_tx`
Converts your 21-bit frames → their 4-byte sequence
- Input: 21-bit data, enable
- Output: 4 sequential 8-bit UART frames
- Handles their `wr_en` and `Tx_busy` protocol

### Module 2: `uart_frame_adapter_rx`
Converts their 4-byte sequence → your 21-bit frames
- Input: 4 sequential 8-bit UART frames
- Output: 21-bit data, ready pulse
- Handles their `ready` and `ready_clr` protocol

### Module 3: `uart_baud_converter`
Handles baud rate conversion (9600 ↔ 115200)
- Option A: Use FIFO buffering
- Option B: Direct clock domain crossing

---

## Connection Diagram

```
Your System (9600 baud, 21-bit frames)
    |
    v
[uart_frame_adapter_tx] ---> [uart_baud_converter] --->
                                                          UART Physical Line
[uart_frame_adapter_rx] <--- [uart_baud_converter] <---
    |
    v
Their System (115200 baud, 4-byte sequence)
```

---

## Impact Assessment

### Performance Impact
- **Latency**: 4-byte transmission at 115200 bps = ~347 µs
- **vs** 21-bit transmission at 9600 bps = ~2.19 ms
- **Result**: Their system is **6.3x faster** for transactions

### Resource Impact
- **Adapter modules**: ~200-300 ALMs (estimated)
- **FIFO buffers**: ~100-200 ALMs for baud conversion
- **Total overhead**: ~400-500 ALMs

### Testing Impact
- Need new testbenches for adapter modules
- Need dual-system testbench with adapters
- Existing testbenches remain valid

---

## Next Steps

1. **Immediate**: Choose between adapter approach vs. full rewrite
2. **If adapter**: Design and implement 3 adapter modules
3. **If rewrite**: Modify bus_bridge_master.v and bus_bridge_slave.v
4. **Testing**: Create comprehensive cross-system testbench
5. **Validation**: Test with actual FPGA-to-FPGA connection

---

## Implementation Status: COMPLETED ✅

### Files Created:
1. ✅ `rtl/core/uart_to_other_team_tx_adapter.v` - TX adapter (21-bit → 4-byte)
2. ✅ `rtl/core/uart_to_other_team_rx_adapter.v` - RX adapter (2-byte → 8-bit)
3. ✅ `tb/tb_uart_adapters.sv` - Comprehensive adapter testbench
4. ✅ `sim/run_uart_adapter_test.sh` - Simulation script for adapters

### Adapter Module Details

#### uart_to_other_team_tx_adapter.v
**Purpose**: Convert ADS 21-bit frames to other team's 4-byte sequence

**Interface**:
- **Input**: `frame_in[20:0]` = {mode[0], addr[11:0], data[7:0]}
- **Output**: 4 sequential 8-bit UART frames via their UART interface
  - Byte 0: addr[7:0]
  - Byte 1: addr[15:8] (padded with zeros)
  - Byte 2: data[7:0]
  - Byte 3: {7'b0, mode[0]}

**FSM States**: IDLE → SEND_ADDR_L → WAIT_ADDR_L → SEND_ADDR_H → WAIT_ADDR_H → SEND_DATA → WAIT_DATA → SEND_FLAGS → WAIT_FLAGS → IDLE

**Timing**: ~347 µs per transaction at 115200 baud (4 bytes × ~87 µs/byte)

#### uart_to_other_team_rx_adapter.v
**Purpose**: Convert other team's 2-byte response to ADS 8-bit frame

**Interface**:
- **Input**: 2 sequential 8-bit UART frames from their UART
  - Byte 0: data[7:0] (read data)
  - Byte 1: {7'b0, is_write[0]}
- **Output**: `frame_out[7:0]` = data[7:0]

**FSM States**: IDLE → WAIT_FLAGS → OUTPUT_FRAME → IDLE

**Timing**: ~174 µs per response at 115200 baud (2 bytes × ~87 µs/byte)

### Testing

Run the adapter testbench:
```bash
./sim/run_uart_adapter_test.sh
```

**Test Coverage**:
1. ✅ TX Adapter - Write transaction (mode=1, addr=0x123, data=0xAA)
2. ✅ TX Adapter - Read transaction (mode=0, addr=0x456, data=0x00)
3. ✅ RX Adapter - Read response (data=0xBB, is_write=0)
4. ✅ RX Adapter - Write acknowledgement (data=0xCC, is_write=1)

### Integration Notes

**IMPORTANT**: The adapters handle protocol conversion but NOT baud rate conversion. Both systems must be configured to use the same baud rate:

**Option A**: Configure your system to 115200 baud (recommended)
```verilog
// In demo_uart_bridge.v, change line 111:
localparam UART_CLOCKS_PER_PULSE = 434;  // Was 5208 for 9600 baud
```

**Option B**: Configure their system to 9600 baud
```verilog
// In their baudrate.v, change lines 11-14:
parameter RX_ACC_MAX = 50000000 / (9600 * 16);
parameter TX_ACC_MAX = 50000000 / 9600;
```

**Recommendation**: Use Option A (115200 baud) for 12x faster transactions.

### Files to Modify for Full Integration:

**When using adapters with your bus bridge**:
1. Instantiate `uart_to_other_team_tx_adapter` between your `bus_bridge_slave` TX and their UART RX
2. Instantiate `uart_to_other_team_rx_adapter` between their UART TX and your `bus_bridge_master` RX
3. Change `UART_CLOCKS_PER_PULSE = 434` in `demo_uart_bridge.v` for 115200 baud

---

## Conclusion

**The two systems are NOT directly compatible without adapters.** However, protocol adapter modules have been successfully implemented and tested.

**Solution Implemented**: Option 1 (Protocol adapter modules) ✅

**Status**: Ready for integration and FPGA-to-FPGA testing

**Next Steps**:
1. Change baud rate to 115200 in your system (or coordinate with other team for 9600)
2. Integrate adapters into `demo_uart_bridge.v`
3. Test with actual hardware connection between FPGAs
4. Update cross-system testbench (`tb_demo_uart_bridge.sv`) to use adapters

**Performance**:
- Transaction latency with adapters at 115200 baud: ~521 µs (347 µs TX + 174 µs RX)
- vs. Original 21-bit at 9600 baud: ~2.19 ms TX + ~0.83 ms RX = ~3.02 ms
- **Speedup: 5.8x faster with adapters at 115200 baud**
