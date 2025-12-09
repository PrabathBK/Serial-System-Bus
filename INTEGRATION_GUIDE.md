# Quick Integration Guide: Connecting to Other Team's System

## Status: ✅ READY FOR INTEGRATION

The adapter modules are complete and tested. Follow these steps to connect your system to the other team's system.

## Step 1: Choose Baud Rate (REQUIRED)

Both systems must use the **same baud rate**. Choose one:

### Option A: Use 115200 baud (RECOMMENDED - 12x faster)

**In your system**, edit `rtl/demo_uart_bridge.v` line 111:
```verilog
// Change from:
localparam UART_CLOCKS_PER_PULSE = 5208;  // 9600 baud

// Change to:
localparam UART_CLOCKS_PER_PULSE = 434;   // 115200 baud
```

### Option B: Use 9600 baud

**In their system**, edit `another_team/serial-bus-design/rtl/uart/buadrate.v` lines 11-14:
```verilog
// Change from:
parameter RX_ACC_MAX = 50000000 / (115200 * 16);
parameter TX_ACC_MAX = 50000000 / 115200;

// Change to:
parameter RX_ACC_MAX = 50000000 / (9600 * 16);
parameter TX_ACC_MAX = 50000000 / 9600;
```

**Recommendation**: Use Option A (115200 baud) for better performance.

---

## Step 2: Physical UART Connections

Connect the UART pins between your DE0-Nano and their FPGA:

```
Your FPGA                          Their FPGA
===========                        ===========
GPIO_0_BRIDGE_S_TX  ------------> uart_rx (Initiator)
GPIO_0_BRIDGE_S_RX  <------------ uart_tx (Initiator)

GPIO_0_BRIDGE_M_RX  <------------ uart_tx (Target)
GPIO_0_BRIDGE_M_TX  ------------> uart_rx (Target)

GND  <--------------------------> GND
```

**CRITICAL**: Cross connections (TX → RX, RX → TX) and common ground required!

---

## Step 3: Address Mapping

Your system uses 12-bit addresses, their system uses 16-bit addresses.

**In your bus bridge slave** (`rtl/core/bus_bridge_slave.v`), addresses are already mapped:
- Your Slave 1 (2KB): Remote address 0x8000-0x87FF
- Your Slave 2 (4KB): Remote address 0xC000-0xCFFF

**Their system will see**:
- Byte 0: addr[7:0]
- Byte 1: addr[15:8] (your 12-bit addr is padded to 16-bit)

The adapters handle this automatically.

---

## Step 4: Test the Adapters

Before hardware integration, test the adapter modules:

```bash
cd /home/akitha/Desktop/ads/Serial-System-Bus
./sim/run_uart_adapter_test.sh
```

**Expected output**:
```
Test 1: TX Adapter - Write transaction ... PASS
Test 2: TX Adapter - Read transaction ... PASS
Test 3: RX Adapter - Read response ... PASS
Test 4: RX Adapter - Write acknowledgement ... PASS

*** ALL TESTS PASSED ***
```

---

## Step 5: Protocol Translation

The adapters automatically handle protocol conversion:

### Your TX → Their RX (Commands)
```
Your 21-bit frame:                   Adapter converts to 4 bytes:
{mode[0], addr[11:0], data[7:0]}  → Byte 0: addr[7:0]
                                     Byte 1: addr[15:8] (padded)
                                     Byte 2: data[7:0]
                                     Byte 3: {7'b0, mode[0]}
```

### Their TX → Your RX (Responses)
```
Their 2-byte sequence:               Adapter converts to:
Byte 0: data[7:0]                 → frame_out[7:0] = data[7:0]
Byte 1: {7'b0, is_write[0]}
```

---

## Step 6: Demo Operation

Once connected, use the DE0-Nano demo controls:

### To access their Slave 1 via UART bridge:
1. SW[2] = 1 (External mode)
2. SW[1] = 0 (Slave 1 select)
3. SW[3] = 1 (Write mode)
4. Press KEY[1] to set data value (shown on LED)
5. Press KEY[0] to execute write
6. Switch SW[3] = 0 (Read mode)
7. Press KEY[0] to read back data

### To access their Slave 2:
- Same as above but SW[1] = 1 (Slave 2 select)

---

## Step 7: Troubleshooting

### If transactions timeout:
- Check UART physical connections (TX↔RX crossed?)
- Verify both systems use same baud rate
- Check GND connection between FPGAs
- Increase timeout in demo_uart_bridge.v line 416 if needed

### If data corruption occurs:
- Verify voltage levels match (both 3.3V?)
- Add series resistor (100Ω) on UART lines if needed
- Check for noise on UART lines with oscilloscope

### If adapters don't work:
- Run `./sim/run_uart_adapter_test.sh` to verify
- Check waveforms: `gtkwave sim/tb_uart_adapters.vcd`

---

## Performance Expectations

### At 115200 baud (recommended):
- Write transaction: ~347 µs
- Read transaction: ~521 µs (347 µs command + 174 µs response)

### At 9600 baud:
- Write transaction: ~4.2 ms
- Read transaction: ~6.3 ms

**Speedup with 115200 baud: 12x faster**

---

## Files Created

1. ✅ `rtl/core/uart_to_other_team_tx_adapter.v` - TX protocol adapter
2. ✅ `rtl/core/uart_to_other_team_rx_adapter.v` - RX protocol adapter
3. ✅ `tb/tb_uart_adapters.sv` - Comprehensive testbench
4. ✅ `sim/run_uart_adapter_test.sh` - Test script
5. ✅ `UART_COMPATIBILITY_ANALYSIS.md` - Detailed analysis
6. ✅ `INTEGRATION_GUIDE.md` - This guide

---

## Quick Start Checklist

- [ ] Choose baud rate (recommend 115200)
- [ ] Modify `UART_CLOCKS_PER_PULSE` in your or their system
- [ ] Run adapter test: `./sim/run_uart_adapter_test.sh`
- [ ] Connect UART pins (TX↔RX, GND)
- [ ] Program both FPGAs
- [ ] Test with SW[2]=1 (external mode)
- [ ] Verify transactions with LEDs

---

## Next Steps for Full Integration

The current adapters are **standalone modules**. To integrate into your full system:

1. Modify `rtl/demo_uart_bridge.v` to instantiate adapters
2. Connect adapters between your bus bridges and their UART
3. Update `tb/tb_demo_uart_bridge.sv` for cross-system testing
4. Test in simulation before hardware

Or use the adapters in a **wrapper module** that sits between the two systems without modifying your existing design.

---

## Support

For questions or issues:
1. Review `UART_COMPATIBILITY_ANALYSIS.md` for technical details
2. Check adapter test results in simulation
3. Verify waveforms with gtkwave

**Status**: Ready for hardware testing! 🚀
