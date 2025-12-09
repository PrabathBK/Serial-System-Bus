# Protocol Adapter Integration - COMPLETE ✓

## Summary

The protocol adapters have been **fully integrated** into the ADS Serial Bus System. You can now communicate directly with the other team's FPGA using a single DE0-Nano board.

---

## What Was Done

### 1. ✓ Integrated TX Adapter into bus_bridge_slave.v
- **Location:** `rtl/core/bus_bridge_slave.v` lines 97-260
- **Function:** Converts your 21-bit UART frames → Their 4-byte sequence
- **Protocol Flow:**
  ```
  Your Bus → 21-bit frame {mode, addr[11:0], data[7:0]}
         ↓
  TX Adapter → 4 bytes: [addr_l, addr_h, data, flags]
         ↓
  UART TX (115200 baud) → Their bridge_target_uart_rx
  ```

### 2. ✓ Integrated RX Adapter into bus_bridge_master.v
- **Location:** `rtl/core/bus_bridge_master.v` lines 114-247
- **Function:** Converts their 2-byte response → Your 8-bit data frame
- **Protocol Flow:**
  ```
  Their bridge_target_uart_tx → UART RX (115200 baud)
         ↓
  RX Adapter → Extract data byte from 2-byte sequence
         ↓
  Your Bus ← 8-bit data
  ```

### 3. ✓ Updated demo_uart_bridge.v
- **Location:** `rtl/demo_uart_bridge.v` lines 66, 527-570, 653-665
- **Changes:**
  - Added `ENABLE_ADAPTERS` parameter (default = 0 for backward compatibility)
  - Passed parameter to both bridge modules
  - Removed old placeholder adapter code
  - Direct GPIO connections to bridge modules

### 4. ✓ Created Comprehensive Documentation
- **DIRECT_MEMORY_ACCESS_GUIDE.md** - Complete hardware setup guide
  - Hardware connections (GPIO wiring)
  - Switch/button configurations
  - Step-by-step WRITE procedure
  - Step-by-step READ procedure
  - Their memory map
  - Address limitations
  - Troubleshooting guide
  - Quick reference card

---

## How Adapters Work

### Conditional Compilation (Generate Blocks)

The adapters use Verilog `generate` blocks to conditionally include adapter logic:

**In bus_bridge_slave.v:**
```verilog
generate
    if (ENABLE_ADAPTERS == 1) begin : tx_adapter_gen
        // Instantiate TX adapter + UART TX
        uart_to_other_team_tx_adapter tx_adapter (...);
        uart_tx adapter_uart_tx (...);
        // Route through adapter
    end else begin : no_adapter
        // Direct UART connection (original 21-bit protocol)
    end
endgenerate
```

**In bus_bridge_master.v:**
```verilog
generate
    if (ENABLE_ADAPTERS == 1) begin : rx_adapter_gen
        // Instantiate UART RX + RX adapter
        uart_rx adapter_uart_rx (...);
        uart_to_other_team_rx_adapter rx_adapter (...);
        // Route through adapter
    end else begin : no_adapter
        // Direct UART connection
    end
endgenerate
```

### At Synthesis Time
- **ENABLE_ADAPTERS = 0:** Only direct UART modules synthesized (smaller, faster)
- **ENABLE_ADAPTERS = 1:** Adapter logic included (compatible with other team)

---

## How to Use

### For Cross-System Communication (with Other Team)

**1. Enable Adapters:**

Edit `rtl/demo_uart_bridge.v` line 66:
```verilog
parameter ENABLE_ADAPTERS = 1       // Enable for cross-system
```

**2. Synthesize and Program:**
```bash
./scripts/synthesize_and_verify.sh
cd quartus/
quartus_pgm -m jtag -o "p;output_files/ads_bus_system.sof@1"
```

**3. Wire GPIOs:**
```
Your GPIO_0[2] (TX) → Their bridge_target_uart_rx
Your GPIO_0[3] (RX) ← Their bridge_target_uart_tx
Your GND           ↔ Their GND
```

**4. Follow guide:**
See `docs/DIRECT_MEMORY_ACCESS_GUIDE.md` for complete instructions

### For Internal Testing (Dual DE0-Nano)

**1. Keep Adapters Disabled:**
```verilog
parameter ENABLE_ADAPTERS = 0       // Use direct 21-bit protocol
```

**2. Connect two of your own boards:**
```
Board A GPIO_0[2] (Bridge S TX) → Board B GPIO_0[0] (Bridge M RX)
Board A GPIO_0[3] (Bridge S RX) ← Board B GPIO_0[1] (Bridge M TX)
```

---

## File Changes Summary

### Modified Files

| File | Lines Changed | Purpose |
|------|---------------|---------|
| `rtl/core/bus_bridge_slave.v` | 97-260 | Added TX adapter integration |
| `rtl/core/bus_bridge_master.v` | 114-247 | Added RX adapter integration |
| `rtl/demo_uart_bridge.v` | 66, 119, 527-665 | Parameter propagation, cleanup |

### New Files

| File | Purpose |
|------|---------|
| `docs/DIRECT_MEMORY_ACCESS_GUIDE.md` | Complete user guide for cross-system access |
| `ADAPTER_INTEGRATION_COMPLETE.md` | This summary document |

### Existing Files (Unchanged)

| File | Status |
|------|--------|
| `rtl/core/uart_to_other_team_tx_adapter.v` | ✓ Working (tested) |
| `rtl/core/uart_to_other_team_rx_adapter.v` | ✓ Working (tested) |
| `tb/tb_uart_adapters.sv` | ✓ All tests pass |

---

## Testing Status

### ✓ Adapter Tests (Standalone)
- **Test script:** `sim/run_uart_adapter_test.sh`
- **Results:** All 4 tests PASS
  - Test 1: TX adapter write sequence ✓
  - Test 2: TX adapter read sequence ✓
  - Test 3: RX adapter read response ✓
  - Test 4: RX adapter write ACK ✓

### ⏳ Integration Tests (Pending Hardware)
- **Internal loop-back:** Not tested yet (requires 2 FPGAs)
- **Cross-system:** Not tested yet (requires other team's FPGA)

**Recommendation:** Test with hardware using procedures in `DIRECT_MEMORY_ACCESS_GUIDE.md`

---

## Protocol Compatibility

### Your System (ADS)
- **Frame format:** 21 bits = {mode[0], addr[11:0], data[7:0]}
- **Baud rate:** 115200 (changed from 9600)
- **UART:** Single frame per transaction

### Other Team's System
- **TX (commands):** 4 bytes = [addr_l, addr_h, data, flags]
- **RX (responses):** 2 bytes = [data, flags]
- **Baud rate:** 115200
- **UART:** Multi-byte sequence

### Adapter Conversion
✓ **TX Adapter:** 21-bit → 4-byte (implemented in bus_bridge_slave)
✓ **RX Adapter:** 2-byte → 8-bit (implemented in bus_bridge_master)

---

## Memory Access Capabilities

### What You CAN Access
- ✓ Their **Target 0:** Addresses **0x0000 - 0x07FF** (2KB)
  - Full read/write access
  - Compatible with your 12-bit addressing

### What You CANNOT Access
- ✗ Their **Target 1:** Addresses 0x4000+ (requires bit 14)
- ✗ Their **Bridge:** Addresses 0x8000+ (requires bit 15)
- **Reason:** Your system uses 12-bit addresses (0x000-0xFFF), limited to lower 4KB

### Workarounds
See `DIRECT_MEMORY_ACCESS_GUIDE.md` section "Address Limitations" for options

---

## Known Limitations

### 1. Address Width Mismatch
- **Your addresses:** 12 bits (4KB range)
- **Their addresses:** 16 bits (64KB range)
- **Impact:** Can only access their lower 4KB

### 2. No Cross-System Simulation
- Module name conflicts prevent dual-system testbench
- **Workaround:** Test with real hardware

### 3. One-Way Initiation
- Current guide covers YOU sending commands to THEM
- For them to initiate, use their button (btn_trigger)
- Your bus_bridge_master will receive and execute

---

## Performance Notes

### Transaction Time (Estimated)
```
115200 baud = 11520 bytes/sec = ~87 μs per byte

Write transaction (YOU → THEM):
  TX: 4 bytes × 87 μs = 348 μs (send)
  RX: 2 bytes × 87 μs = 174 μs (ACK)
  Total: ~522 μs (~520 microseconds)

Read transaction (YOU → THEM):
  TX: 4 bytes × 87 μs = 348 μs (request)
  RX: 2 bytes × 87 μs = 174 μs (data)
  Total: ~522 μs (~520 microseconds)
```

**Throughput:** ~1900 transactions/second

### Timing Parameters
- **Timeout:** 500,000 clock cycles @ 50MHz = 10ms (demo_uart_bridge.v:419)
- **Debounce:** 50,000 clock cycles = 1ms (demo_uart_bridge.v:64)

---

## Design Decisions

### Why Integrate Inside Bridge Modules?
1. **Cleaner interface:** GPIO pins connect directly to bridge modules
2. **Single parameter:** One `ENABLE_ADAPTERS` switch controls everything
3. **No external wiring:** Adapters hidden inside bridge logic
4. **Backward compatible:** Works with existing code when disabled

### Alternative Approaches Considered
- **External adapter FPGA:** More hardware, but flexible
- **Top-level wiring:** Clutters demo_uart_bridge.v
- **Always-on adapters:** No backward compatibility

### Chosen Approach Benefits
✓ Single-FPGA solution
✓ Clean top-level design
✓ Works with existing tests
✓ Easy to switch modes

---

## Next Steps

### For You (To Test Hardware)
1. Set `ENABLE_ADAPTERS = 1` in demo_uart_bridge.v
2. Synthesize and program your FPGA
3. Coordinate with other team for pins and addresses
4. Wire GPIOs according to guide
5. Follow test procedures in `DIRECT_MEMORY_ACCESS_GUIDE.md`

### For Further Development
1. **Extend address width** (if needed):
   - Change `BB_ADDR_WIDTH` from 12 to 16
   - Update all bridge modules
   - Resynthesize

2. **Add bidirectional testing:**
   - Test their button-triggered initiator
   - Verify your bus_bridge_master receives correctly

3. **Performance optimization:**
   - Reduce timeouts after successful testing
   - Optimize adapter state machines

---

## References

### Documentation
- `docs/DIRECT_MEMORY_ACCESS_GUIDE.md` - **START HERE for hardware testing**
- `CROSS_SYSTEM_INTEGRATION_STATUS.md` - Overall project status
- `SYMMETRIC_MODULE_COMPATIBILITY_ANALYSIS.md` - Their system analysis
- `UART_COMPATIBILITY_ANALYSIS.md` - Protocol differences

### Source Files
- `rtl/core/bus_bridge_slave.v` - TX path (you → them)
- `rtl/core/bus_bridge_master.v` - RX path (them → you)
- `rtl/core/uart_to_other_team_tx_adapter.v` - 21-bit → 4-byte
- `rtl/core/uart_to_other_team_rx_adapter.v` - 2-byte → 8-bit
- `rtl/demo_uart_bridge.v` - Top-level wrapper

### Test Files
- `tb/tb_uart_adapters.sv` - Adapter unit tests
- `sim/run_uart_adapter_test.sh` - Test script

---

## Support

For questions or issues:
1. Check `DIRECT_MEMORY_ACCESS_GUIDE.md` troubleshooting section
2. Review waveforms: `gtkwave sim/tb_uart_adapters.vcd`
3. Check synthesis reports in `quartus/output_files/`

---

**Status:** ✅ INTEGRATION COMPLETE - READY FOR HARDWARE TESTING

**Date:** December 9, 2025
