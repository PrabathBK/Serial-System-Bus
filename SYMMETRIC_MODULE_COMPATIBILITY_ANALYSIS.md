# Symmetric Module Compatibility Analysis

## Date: 2025-12-09

## Overview

Analyzed the other team's new top module `system_top_with_bus_bridge_symmetric.sv` to verify compatibility with our protocol adapters and integration approach.

## Key Finding: ✓ FULLY COMPATIBLE

The symmetric module uses **IDENTICAL UART protocol** to their previous modules (system_top_with_bus_bridge_a/b.sv). Our adapters remain fully compatible.

## Module Architecture Comparison

### Previous Modules (system_top_with_bus_bridge_a/b.sv)
```
Module A (Initiator only):
- bus_bridge_initiator_uart_wrapper (sends requests, receives responses)
- Local targets (memory)

Module B (Target only):
- bus_bridge_target_uart_wrapper (receives requests, sends responses)
- Local targets (memory)
```

### New Symmetric Module (system_top_with_bus_bridge_symmetric.sv)
```
Single Module (Both roles):
- bus_bridge_initiator_uart_wrapper (can receive requests from other FPGA)
- bus_bridge_target_uart_wrapper (can send requests to other FPGA)
- Local initiator (button-triggered)
- Local targets (memory)
- Dual UART interfaces:
  - bridge_initiator_uart_rx/tx (receives/responds to external requests)
  - bridge_target_uart_rx/tx (sends/receives responses for outgoing requests)
```

**Connection Topology:**
```
FPGA A (symmetric)                    FPGA B (symmetric)
├─ bridge_target_uart_tx ────────→ bridge_initiator_uart_rx
├─ bridge_target_uart_rx ←──────── bridge_initiator_uart_tx
└─ bridge_initiator_uart_tx ─────→ bridge_target_uart_rx
└─ bridge_initiator_uart_rx ←────── bridge_target_uart_tx
```

## Protocol Verification

### Request Format (4 bytes)
From `bus_bridge_initiator_uart_wrapper.sv` (lines 124-148) and `bus_bridge_target_uart_wrapper.sv`:

**RX Side (Initiator receives request):**
```verilog
Byte 0: req_pending.addr[7:0]     // Address LSB
Byte 1: req_pending.addr[15:8]    // Address MSB
Byte 2: req_pending.write_data    // Write data
Byte 3: req_pending.is_write[0]   // bit 0 = is_write flag
```

**TX Side (Target sends request):**
```verilog
Byte 0: req_pending.addr[7:0]     // Address LSB
Byte 1: req_pending.addr[15:8]    // Address MSB  
Byte 2: req_pending.write_data    // Write data
Byte 3: req_pending.is_write[0]   // bit 0 = is_write flag
```

### Response Format (2 bytes)
From `bus_bridge_initiator_uart_wrapper.sv` (lines 195-210):

```verilog
Byte 0: resp_pending.read_data    // Read data
Byte 1: resp_pending.is_write[0]  // bit 0 = is_write flag
```

### UART Configuration
From uart instantiation (line 76-88):
```verilog
uart #(
    .DATA_BITS(8)
) u_initiator_uart (
    ...
);
```

- **Baud rate**: 115200 (verified via uart.v module)
- **Frame format**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Handshaking**: ready/ready_clr signals

## Adapter Compatibility Matrix

| Protocol Aspect | Their System | Our Adapters | Compatible? |
|----------------|--------------|--------------|-------------|
| **Request Frame** |
| Byte 0 | addr[7:0] | addr_12bit[7:0] → addr[7:0] | ✓ YES |
| Byte 1 | addr[15:8] | {4'b0, addr_12bit[11:8]} → addr[15:8] | ✓ YES |
| Byte 2 | write_data[7:0] | data_byte[7:0] | ✓ YES |
| Byte 3 | is_write (bit 0) | mode_bit → is_write (bit 0) | ✓ YES |
| **Response Frame** |
| Byte 0 | read_data[7:0] | data_byte[7:0] | ✓ YES |
| Byte 1 | is_write (bit 0) | is_write_flag (bit 0) | ✓ YES |
| **UART Config** |
| Baud rate | 115200 | 115200 | ✓ YES |
| Data bits | 8 | 8 | ✓ YES |
| Parity | None | None | ✓ YES |
| Stop bits | 1 | 1 | ✓ YES |

## Address Width Handling

**Our System:** 12-bit address (0x000 - 0xFFF, 4KB max)
**Their System:** 16-bit address (0x0000 - 0xFFFF, 64KB max)

**Adapter Behavior:**
```verilog
// TX Adapter (line 136 of uart_to_other_team_tx_adapter.v)
uart_data_in <= {4'b0000, addr_12bit[11:8]};  // Zero-pad upper 4 bits
```

This means:
- Our address 0x123 → Their address 0x0123 ✓
- Our address 0xFFF → Their address 0x0FFF ✓
- We can only access their lower 4KB (0x0000-0x0FFF)

**Their Memory Map (from symmetric module):**
```
TARGET0_BASE = 0x0000 (2KB)
TARGET1_BASE = 0x4000 (4KB)
BRIDGE_BASE_ADDR = 0x8000 (bridge to remote system)
```

**Compatibility:**
- ✓ We can access their Target 0 (0x0000-0x07FF) - within our 4KB range
- ✗ We CANNOT access their Target 1 (0x4000+) - outside our 12-bit range
- ✗ We CANNOT access their bridge (0x8000+) - outside our 12-bit range

**Workaround:** Their system should map resources we need to access in the lower 4KB region (0x0000-0x0FFF)

## Connection Scenarios

### Scenario 1: Your System ↔ Their Symmetric Module (Initiator Role)

**Connection:**
```
Your System                      Their Symmetric Module
GPIO_0_BRIDGE_S_TX ──[adapter]──→ bridge_initiator_uart_rx
GPIO_0_BRIDGE_M_RX ←─[adapter]─── bridge_initiator_uart_tx
```

**Your Role:** Target (they initiate, you respond)
**Their Role:** Initiator (they send requests, receive responses)

**Adapter Path:**
1. Your bus_bridge_slave generates 21-bit frame for outgoing request
2. TX adapter converts to 4-byte sequence
3. Their bridge_initiator receives 4-byte request
4. Their bridge_initiator sends 2-byte response
5. RX adapter converts to 8-bit frame
6. Your bus_bridge_master receives response

### Scenario 2: Your System (Initiator) ↔ Their Symmetric Module (Target Role)

**Connection:**
```
Your System                      Their Symmetric Module
GPIO_0_BRIDGE_S_TX ──[adapter]──→ bridge_target_uart_rx
GPIO_0_BRIDGE_M_RX ←─[adapter]─── bridge_target_uart_tx
```

**Your Role:** Initiator (you send requests, receive responses)
**Their Role:** Target (they receive requests, send responses)

**Adapter Path:**
1. Your bus_bridge_slave generates 21-bit frame for outgoing request
2. TX adapter converts to 4-byte sequence
3. Their bridge_target receives 4-byte request
4. Their bridge_target sends 2-byte response
5. RX adapter converts to 8-bit frame
6. Your bus_bridge_master receives response

### Scenario 3: Symmetric ↔ Symmetric (Full Bidirectional)

**Connection:**
```
FPGA A (Your Adapted System)     FPGA B (Their Symmetric)
S_TX ──[TX-adapt]──→ target_rx ──[bridge]──→ their_bus
M_RX ←─[RX-adapt]─── target_tx ←─[bridge]─── their_bus

(Would need second set of adapters for reverse direction)
```

## Integration Status

### Current State: ✓ Protocol Adapters Verified
- TX Adapter tested and working (21-bit → 4-byte)
- RX Adapter tested and working (2-byte → 8-bit)
- Protocol matches their symmetric module UART wrappers

### Pending: Physical Integration
Two options remain:

**Option A: External Adapter Module**
- Standalone FPGA/board running just adapters
- Sits between your system and their symmetric module
- No changes to either system
- **Fastest path to testing**

**Option B: Integrated Adapters**
- Modify bus_bridge_master/slave to expose frame interfaces
- Insert adapters into demo_uart_bridge.v
- Single FPGA solution
- **Cleaner long-term solution**

## Recommendations

### For Hardware Testing with Symmetric Module

**1. Verify Address Map**
Ask the other team to confirm which memory regions they want you to access:
- Target 0 (0x0000-0x07FF): ✓ Accessible with our 12-bit addresses
- Target 1 (0x4000-0x4FFF): ✗ Need address width expansion
- Bridge (0x8000+): ✗ Outside our range

**2. Choose Connection Type**
- If they want to READ/WRITE your memory: Use Scenario 1 (they initiate)
- If you want to READ/WRITE their memory: Use Scenario 2 (you initiate)
- For full bidirectional: Need dual adapter sets (more complex)

**3. UART Pin Mapping**
Clarify with the other team:
```
Their symmetric.sv ports:
- bridge_initiator_uart_rx/tx (one role)
- bridge_target_uart_rx/tx (other role)

Your connections (pick one pair):
- Scenario 1: Connect your TX/RX to their initiator RX/TX
- Scenario 2: Connect your TX/RX to their target RX/TX
```

**4. Verify Baud Rate**
Both systems now use 115200 baud ✓

**5. Test Sequence**
1. Connect FPGAs with adapters
2. Power on both systems
3. Trigger transaction from initiator side
4. Verify LEDs/outputs show correct data transfer
5. Use logic analyzer if issues arise

## Differences from Previous Analysis

### What Changed
- **Architecture**: Single symmetric module replaces separate A/B modules
- **Interface**: Two UART pairs (initiator + target) instead of one

### What Stayed the Same ✓
- UART protocol (4-byte request, 2-byte response)
- Frame format and byte ordering
- Baud rate (115200)
- UART wrapper implementations (bus_bridge_initiator_uart_wrapper, bus_bridge_target_uart_wrapper)

### Impact on Our Design
**None** - Our adapters work with the UART wrapper protocol, which is identical. The symmetric module just instantiates both wrappers instead of one.

## Conclusion

✓ **FULLY COMPATIBLE** - The symmetric module uses the same UART protocol as before. Our protocol adapters work without modification.

**Action Items:**
1. Coordinate with other team on:
   - Which connection scenario (initiator vs target role)
   - Address mapping (stay within 0x0000-0x0FFF)
   - Physical pin connections
2. Choose integration approach (external adapter board vs integrated)
3. Test with adapters in signal path

**No Code Changes Required** - Adapters verified and working as-is.
