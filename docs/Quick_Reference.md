# ADS Bus System - Quick Reference Guide

## Project Summary
**ADS Bus System** - Serial communication bus for FPGA  
**Platform**: Terasic DE10-Nano (Intel Cyclone V 5CSEBA6U23I7)  
**Version**: 1.0 | **Date**: October 14, 2025

---

## Memory Configuration

| Slave | Device ID | Size | Addresses | Split? |
|-------|-----------|------|-----------|--------|
| 1 | 0x0 (4'b0000) | 2KB | 0x0000-0x07FF | No |
| 2 | 0x1 (4'b0001) | 4KB | 0x1000-0x1FFF | No |
| 3 | 0x2 (4'b0010) | 4KB | 0x2000-0x2FFF | Yes |

---

## File Locations

### RTL Source Files
- **Top-level**: `rtl/ads_bus_top.v`
- **Bus Core**: `rtl/core/bus_m2_s3.v`
- **All Modules**: `rtl/core/*.v`

### Synthesis Files
- **Project**: `quartus/ads_bus_system.qpf`
- **Settings**: `quartus/ads_bus_system.qsf`
- **Constraints**: `constraints/ads_bus_system.sdc`

### Documentation
- **Full Doc**: `docs/ADS_Bus_System_Documentation.md`
- **Requirements**: `docs/requirement.txt`
- **Pin Map**: `pin_assignments/DE10_Nano_Pin_Assignments.md`

### Testbenches
- **Main TB**: `tb/master2_slave3_tb.sv`
- **Simple TB**: `tb/simple_read_test.sv`

---

## Quick Synthesis Commands

### Using Quartus GUI
```bash
quartus quartus/ads_bus_system.qpf
# Then: Processing → Start Compilation
```

### Using Command Line
```bash
cd quartus
quartus_sh --flow compile ads_bus_system
```

### Check Results
```bash
# Timing report
cat output_files/ads_bus_system.sta.rpt | grep -A 10 "Slow 1200mV 100C Model Fmax Summary"

# Resource usage
cat output_files/ads_bus_system.fit.summary
```

---

## Quick Simulation

### Using ModelSim (if available)
```bash
cd sim
vlib work
vlog ../rtl/core/*.v ../rtl/ads_bus_top.v
vlog -sv ../tb/master2_slave3_tb.sv
vsim -c -do "run -all; quit" master2_slave3_tb
```

### Using Vivado XSim
```bash
cd sim
xvlog --work work ../rtl/core/*.v
xvlog --work work -sv ../tb/master2_slave3_tb.sv
xelab work.master2_slave3_tb -debug typical
xsim work.master2_slave3_tb -runall
```

---

## Signal Reference

### Master Interface Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| rdata | Output | 1 | Read data (serial) |
| wdata | Input | 1 | Write data (serial) |
| mode | Input | 1 | 0=Read, 1=Write |
| mvalid | Input | 1 | Master valid |
| svalid | Output | 1 | Slave valid |
| breq | Input | 1 | Bus request |
| bgrant | Output | 1 | Bus grant |
| ack | Output | 1 | Acknowledge |
| split | Output | 1 | Split transaction |

### LED Indicators

| LED | Status |
|-----|--------|
| 0 | Reset (ON = running) |
| 1 | Master 1 has bus |
| 2 | Master 2 has bus |
| 3 | Master 1 acknowledged |
| 4 | Master 2 acknowledged |
| 5 | Master 1 split mode |
| 6 | Master 2 split mode |
| 7 | Reserved |

---

## Protocol Cheat Sheet

### Write Transaction Flow
```
1. Assert breq
2. Wait for bgrant
3. Set mode = 1 (write)
4. Assert mvalid
5. Send device addr (4 bits, MSB-first)
6. Send memory addr (11-12 bits, LSB-first)
7. Wait for ack
8. Send data (8 bits, LSB-first)
9. Clear mvalid and breq
```

### Read Transaction Flow
```
1. Assert breq
2. Wait for bgrant
3. Set mode = 0 (read)
4. Assert mvalid
5. Send device addr (4 bits, MSB-first)
6. Send memory addr (11-12 bits, LSB-first)
7. Wait for ack
8. Wait for svalid
9. Receive data (8 bits, LSB-first)
10. Clear mvalid and breq
```

### Bit Order Summary
- **Device Address**: MSB-first (bits 3→2→1→0)
- **Memory Address**: LSB-first (bits 0→1→2→...→10/11)
- **Data**: LSB-first (bits 0→1→2→...→7)

---

## Resource Usage (Expected)

| Resource | Used | Available | % |
|----------|------|-----------|---|
| ALMs | 500-800 | 110,000 | <1% |
| Registers | 300-500 | 220,000 | <1% |
| M10K Blocks | 10 | 553 | 1.8% |
| I/O Pins | 27 | 457 | 5.9% |

**Memory Breakdown**:
- Slave 1: 2 M10K blocks (2KB)
- Slave 2: 4 M10K blocks (4KB)
- Slave 3: 4 M10K blocks (4KB)

---

## Pin Assignments (DE10-Nano)

### Clock & Reset
- **FPGA_CLK1_50**: PIN_V11 (50 MHz clock)
- **KEY0**: PIN_AH17 (Reset button, active low)

### LEDs
- **LED[0-7]**: PIN_W15, AA24, V16, V15, AF26, AE26, Y16, AA23

### Master 1 GPIO (Arduino Header)
- **GPIO_M1_RDATA**: PIN_AG9
- **GPIO_M1_WDATA**: PIN_AF10
- **GPIO_M1_MODE**: PIN_AG10
- **GPIO_M1_MVALID**: PIN_AF8
- **GPIO_M1_SVALID**: PIN_AF9
- **GPIO_M1_BREQ**: PIN_AD11
- **GPIO_M1_BGRANT**: PIN_AD12
- **GPIO_M1_ACK**: PIN_AE11
- **GPIO_M1_SPLIT**: PIN_AE12

### Master 2 GPIO (Arduino Header)
- **GPIO_M2_RDATA**: PIN_AF17
- **GPIO_M2_WDATA**: PIN_AF15
- **GPIO_M2_MODE**: PIN_AG16
- **GPIO_M2_MVALID**: PIN_AG15
- **GPIO_M2_SVALID**: PIN_AH14
- **GPIO_M2_BREQ**: PIN_AG14
- **GPIO_M2_BGRANT**: PIN_AH8
- **GPIO_M2_ACK**: PIN_AF11
- **GPIO_M2_SPLIT**: PIN_AG11

---

## Timing Constraints

- **Clock Period**: 20 ns (50 MHz)
- **Input Delay**: 1-3 ns
- **Output Delay**: 0-2 ns
- **Expected Fmax**: > 100 MHz

---

## Common Issues & Solutions

### Issue: Compilation Fails
**Solution**: Check that all source files are in correct directories:
- `rtl/ads_bus_top.v`
- `rtl/core/*.v` (11 files)

### Issue: Timing Not Met
**Solution**: Already optimized for 50 MHz. If issues:
1. Check SDC file loaded correctly
2. Verify clock constraint on PIN_V11
3. Try higher optimization settings in QSF

### Issue: Simulation Shows X's
**Solution**:
1. Ensure reset asserted for at least 3 clock cycles
2. Initialize all inputs before first transaction
3. Check for proper clock generation in testbench

### Issue: FPGA Not Responding
**Solution**:
1. Verify .sof file programmed successfully
2. Check LED[0] is ON (reset status)
3. Verify clock source (50 MHz should be present)
4. Check JTAG connection and power

---

## Testbench Results (Last Run)

✅ **77 PASS / 0 ERROR**

- 20 iterations of comprehensive testing
- Random addresses and data patterns
- Arbitration priority verification
- Split transaction handling
- Write-after-write and read-after-write checks

---

## Next Steps for Users

1. **First-Time Setup**:
   - Open Quartus project: `quartus/ads_bus_system.qpf`
   - Run full compilation
   - Program DE10-Nano with generated .sof file

2. **Verification**:
   - Check LEDs respond to reset button (KEY0)
   - Connect external master device to GPIO
   - Test simple write/read transactions

3. **Customization**:
   - Modify memory sizes in `bus_m2_s3.v` parameters
   - Add more slaves (up to 13 more possible)
   - Adjust timing constraints if different clock used

4. **Advanced**:
   - Integrate with HPS (ARM processor on DE10-Nano)
   - Add DMA capability
   - Implement burst mode

---

## Support & Documentation

- **Full Documentation**: See `docs/ADS_Bus_System_Documentation.md`
- **Pin Details**: See `pin_assignments/DE10_Nano_Pin_Assignments.md`
- **Requirements**: See `docs/requirement.txt`

---

**Project Status**: ✅ Ready for Synthesis and FPGA Implementation

**All RTL complete | All documentation complete | All testbenches passing**

---

*October 14, 2025 | ADS Bus System Team*
