# UART Adapter Quick Start Guide

## ✅ Status: READY FOR USE

The UART adapters have been **enabled** in `demo_uart_bridge.v` and are ready for cross-system communication with the other team's bus system.

## What Was Done

1. **Enabled Adapters:** Changed `ENABLE_ADAPTERS = 0` → `ENABLE_ADAPTERS = 1` in `rtl/demo_uart_bridge.v:66`
2. **Verified Integration:** Confirmed adapters are properly integrated in bridge modules
3. **Tested Adapters:** All 4 unit tests passed successfully

## How the Adapters Work

### Your ADS System (21-bit Protocol)
- Frame format: `{mode[1bit], addr[12bits], data[8bits]}`
- UART: 115200 baud, 8N1
- Sends 21 bits as a continuous frame

### Other Team's System (4-byte/2-byte Protocol)  
- Command format: 4 bytes (addr_low, addr_high, data, flags)
- Response format: 2 bytes (data, flags)
- UART: 115200 baud, 8N1
- Sends/receives individual bytes

### The Adapters Bridge The Gap
- **TX Adapter** (`uart_to_other_team_tx_adapter.v`): Converts your 21-bit frames → their 4-byte sequence
- **RX Adapter** (`uart_to_other_team_rx_adapter.v`): Converts their 2-byte response → your 8-bit data

## Testing the Adapters

### Run Unit Tests (Simulation)
```bash
cd /home/akitha/Desktop/ads/Serial-System-Bus
./sim/run_uart_adapter_test.sh
```

Expected output: `*** ALL TESTS PASSED ***`

View waveforms:
```bash
gtkwave tb_uart_adapters.vcd
```

## Using with Hardware

### 1. Synthesize the Design
```bash
./scripts/synthesize_and_verify.sh
```

### 2. Program the FPGA
```bash
quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"
```

### 3. Connect to Other Team's FPGA

**GPIO Connections:**
```
Your FPGA              Other Team's FPGA
-----------            ------------------
GPIO_0_BRIDGE_S_TX  →  Their Bridge Initiator RX
GPIO_0_BRIDGE_S_RX  ←  Their Bridge Initiator TX
GPIO_0_BRIDGE_M_TX  →  Their Bridge Target RX  
GPIO_0_BRIDGE_M_RX  ←  Their Bridge Target TX
GND                 -  GND (common ground!)
```

### 4. Test Communication

**Write to Remote Slave:**
1. Set SW[2]=1 (External mode)
2. Set SW[1]=0 or 1 (Remote Slave 1 or 2)
3. Set SW[3]=1 (Write mode)
4. Press KEY[1] to set data value (increments LED display)
5. Press KEY[0] to send write command via UART

**Read from Remote Slave:**
1. Set SW[2]=1 (External mode)
2. Set SW[1]=0 or 1 (Remote Slave 1 or 2)
3. Set SW[3]=0 (Read mode)
4. Press KEY[1] to set address offset
5. Press KEY[0] to send read request via UART
6. LED will display the read data

## Troubleshooting

### No Communication
- Check physical GPIO connections
- Verify both FPGAs are programmed and running
- Ensure common ground is connected
- Check baud rate: both should be 115200

### Wrong Data Received
- Verify adapter protocol matches other team's implementation
- Check waveforms with SignalTap or logic analyzer
- Review docs: `docs/UART_Bridge_Protocol_Spec.md`

### Simulation Issues
- Use adapter unit test: `./sim/run_uart_adapter_test.sh`
- Full cross-system simulation has module conflicts (use hardware instead)

## Key Files

- **Main Top Module:** `rtl/demo_uart_bridge.v` (adapters enabled)
- **TX Adapter:** `rtl/core/uart_to_other_team_tx_adapter.v`
- **RX Adapter:** `rtl/core/uart_to_other_team_rx_adapter.v`
- **Bridge Master:** `rtl/core/bus_bridge_master.v` (adapters integrated)
- **Bridge Slave:** `rtl/core/bus_bridge_slave.v` (adapters integrated)
- **Test:** `tb/tb_uart_adapters.sv`

## Protocol Reference

### TX: ADS → Other Team (4 bytes)
```
Byte 0: addr[7:0]        Address LSB
Byte 1: addr[15:8]       Address MSB (upper 4 bits = 0)
Byte 2: data[7:0]        Data
Byte 3: {7'b0, mode}     Write flag (bit 0)
```

### RX: Other Team → ADS (2 bytes)
```
Byte 0: data[7:0]        Read data
Byte 1: {7'b0, is_write} Flags
```

## Support Documents

- `ADAPTER_INTEGRATION_SUMMARY.md` - Detailed implementation report
- `docs/UART_Bridge_Protocol_Spec.md` - Your protocol specification
- `another_team/serial-bus-design/` - Other team's RTL source

---

**Ready to test on hardware!** 🚀
