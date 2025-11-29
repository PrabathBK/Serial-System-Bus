# ADS Bus System - Quick Start Guide

**Status**: ✅ BUILD COMPLETE - Ready to Program

---

## ⚡ 60-Second Quick Start

### 1. Verify Files Present
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus
ls -lh ads_bus_system.sof
# Should show: 6.4 MB file
```

### 2. Connect Hardware
- Power on DE10-Nano (5V supply)
- Connect USB cable (JTAG)
- Wait 5 seconds for USB enumeration

### 3. Program FPGA
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus
quartus_pgm -m jtag -o "p;ads_bus_system.sof@1"
```

### 4. Verify Success
- **LED[0]** should be **SOLID ON**
- Programming takes 10-15 seconds
- If LED[0] is OFF, press/release KEY0 button

---

## 📊 Build Summary

| Metric | Result |
|--------|--------|
| **Status** | ✅ Synthesis Complete |
| **Errors** | 0 |
| **Timing** | +7.7ns slack @ 50 MHz |
| **Fmax** | 81.5 MHz (63% margin) |
| **Resources** | 408 ALMs (< 1%) |
| **Memory** | 10 M10K blocks |
| **Tests** | 97/97 PASS |

---

## 🎯 What This Design Does

**ADS Bus System** - Serial Communication Bus with:
- **2 Masters** (priority arbitration)
- **3 Slaves** (2KB + 4KB + 4KB memory)
- **Split Transactions** (Slave 3)
- **Address Decoder** (16-bit addressing)
- **Bus Arbiter** (fixed priority: M1 > M2)

**External Interface**:
- 18 GPIO pins for master connections
- 8 LEDs for status indicators
- 50 MHz clock input
- Active-low reset (KEY0)

---

## 📍 LED Status Indicators

| LED | Function | Behavior |
|-----|----------|----------|
| LED[0] | System Active | ✅ Solid ON after reset |
| LED[1] | Master 1 Bus Request | Flashes when M1 active |
| LED[2] | Master 2 Bus Request | Flashes when M2 active |
| LED[3] | Master 1 Acknowledge | Pulses during M1 ACK |
| LED[4] | Master 2 Acknowledge | Pulses during M2 ACK |
| LED[5] | Master 1 Split | ON during M1 split |
| LED[6] | Master 2 Split | ON during M2 split |
| LED[7] | Reserved | OFF |

---

## 📁 Key Files

### Programming
- **ads_bus_system.sof** (6.4 MB) - FPGA bitstream

### Documentation
- **FPGA_Programming_Guide.md** - Detailed programming instructions
- **Final_Status_Report.md** - Complete project summary
- **ADS_Bus_System_Documentation.md** - Full technical specs
- **DE10_Nano_Pin_Assignments.md** - Pin mapping reference

### Source Code
- **rtl/ads_bus_top.v** - Top-level FPGA wrapper
- **rtl/core/** - 10 core modules
- **tb/** - 2 testbenches (97 tests)

### Build Reports
- **ads_bus_system.fit.rpt** - Resource utilization
- **ads_bus_system.sta.rpt** - Timing analysis
- **ads_bus_system.map.rpt** - Synthesis details

---

## 🔧 GPIO Pin Assignments

### Master 1 Interface (9 signals)
| Signal | Direction | Pin | Arduino Header |
|--------|-----------|-----|----------------|
| HBUSREQ | Input | PIN_AG9 | - |
| HGRANT | Output | PIN_AE12 | - |
| HADDR[15:0] | Input | Serial | - |
| HWRITE | Input | PIN_AD11 | - |
| HWDATA | Input | PIN_AF8 | - |
| HLOCK | Input | PIN_AF9 | - |
| HRDATA | Output | PIN_AD12 | - |
| HACK | Output | PIN_AE11 | - |
| HSPLIT | Output | PIN_AF11 | - |

### Master 2 Interface (9 signals)
| Signal | Direction | Pin | Arduino Header |
|--------|-----------|-----|----------------|
| HBUSREQ | Input | PIN_AF17 | - |
| HGRANT | Output | PIN_AE15 | - |
| HADDR[15:0] | Input | Serial | - |
| HWRITE | Input | PIN_AG18 | - |
| HWDATA | Input | PIN_AH18 | - |
| HLOCK | Input | PIN_AG11 | - |
| HRDATA | Output | PIN_AH19 | - |
| HACK | Output | PIN_AG20 | - |
| HSPLIT | Output | PIN_AF16 | - |

**Full pin list**: See `pin_assignments/DE10_Nano_Pin_Assignments.md`

---

## 🧪 Testing Options

### Option 1: Visual LED Test (No Equipment)
1. Program FPGA
2. Observe LED[0] = ON
3. Internal test pattern may show brief LED activity

### Option 2: External Master Test (GPIO)
1. Connect microcontroller to Master 1 GPIO
2. Drive HBUSREQ high
3. Wait for HGRANT
4. Send address/data transactions
5. Monitor HACK and HRDATA

### Option 3: SignalTap Logic Analyzer
1. Open Quartus project
2. Tools → SignalTap II
3. Add internal signals (arbiter, decoder, etc.)
4. Recompile and re-program
5. Trigger and capture waveforms

---

## 🚨 Troubleshooting

### "No JTAG cable detected"
```bash
# Check USB connection
lsusb | grep -i altera

# Test JTAG chain
quartus_pgm -l
quartus_pgm -c 1 -a

# Fix permissions (Linux)
sudo usermod -a -G dialout $USER
```

### "Programming failed"
- Power cycle DE10-Nano (5 seconds)
- Check USB cable connection
- Try lower JTAG clock: `--frequency=6M`

### "LED[0] stays OFF"
- Press and release KEY0 (reset button)
- Check 50 MHz clock present on PIN_V11
- Re-program FPGA

### "USB Blaster driver not found" (Windows)
- Device Manager → Update Driver
- Browse to: `<quartus_install>/drivers/usb-blaster-ii`
- Select Altera USB-Blaster II driver

---

## 📚 Documentation Structure

```
docs/
├── FPGA_Programming_Guide.md      ← Detailed programming instructions
├── Final_Status_Report.md         ← Complete project summary
├── ADS_Bus_System_Documentation.md← Full technical specifications
├── Quick_Reference.md             ← Quick lookup guide
└── Synthesis_Instructions.md      ← Build process details

pin_assignments/
└── DE10_Nano_Pin_Assignments.md   ← Complete pin mapping

SYNTHESIS_SUCCESS.md               ← Build achievement summary
QUICK_START.md                     ← This file
```

---

## 🎓 Memory Map Reference

| Slave | Device ID | Size | Address Range | Split |
|-------|-----------|------|---------------|-------|
| **Slave 1** | 0x0 | 2 KB | 0x0000-0x07FF | No |
| **Slave 2** | 0x1 | 4 KB | 0x1000-0x1FFF | No |
| **Slave 3** | 0x2 | 4 KB | 0x2000-0x2FFF | **Yes** |

**Address Format**: `[15:12] = Device ID, [11:0] = Memory Address`

---

## 🔄 Re-Programming

FPGA configuration is **volatile** (SRAM-based). Power cycle erases it.

**To make permanent** (optional):
```bash
# Convert .sof to .pof (Flash programming file)
quartus_cpf -c ads_bus_system.cof

# Program Flash (requires .cof configuration file)
quartus_pgm -m jtag -o "p;ads_bus_system.pof"
```

**Flash programming**: Survives power cycles

---

## 📞 Support

### Issue Reporting
If programming fails:
1. Check `quartus/*.rpt` files for errors
2. Verify .sof file size = 6.4 MB
3. Test JTAG: `quartus_pgm -l`
4. Review logs in console output

### External Resources
- **DE10-Nano User Manual**: [Terasic Website](https://www.terasic.com.tw)
- **Quartus Documentation**: Included with Quartus installation
- **Intel FPGA Forums**: [Intel Community](https://community.intel.com/t5/Intel-FPGA-University-Program/bd-p/fpga-university)

---

## ✅ Success Checklist

Before programming:
- [ ] .sof file exists (6.4 MB)
- [ ] DE10-Nano powered on
- [ ] USB cable connected
- [ ] Quartus Programmer available

After programming:
- [ ] "Successful" message in console
- [ ] LED[0] solid ON
- [ ] No error messages
- [ ] Programming took 10-15 seconds

---

## 🎯 Next Steps After Programming

1. **Basic Verification**: Check LED[0] is ON
2. **Connect External Masters**: Wire GPIO to test hardware
3. **Run Transactions**: Send read/write operations
4. **Monitor with SignalTap**: Capture internal waveforms
5. **Measure Performance**: Verify transaction timing

---

## 🏆 Achievement Summary

✅ **Build Complete**: All phases successful  
✅ **Timing Met**: +7.7ns slack at 50 MHz  
✅ **Tests Passed**: 97/97 verification tests  
✅ **Resources**: < 1% FPGA utilization  
✅ **Ready**: Production-quality bitstream  

**Time to program**: 10-15 seconds  
**Time to verify**: < 1 minute

---

**🎊 Ready for FPGA Programming! 🎊**

---

**Last Updated**: October 14, 2025  
**Version**: 1.0  
**Status**: ✅ READY FOR DEPLOYMENT
