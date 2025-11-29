# ADS Bus System - FPGA Programming Guide

**Date**: October 14, 2025  
**Target**: Terasic DE10-Nano (Intel Cyclone V 5CSEBA6U23I7)  
**Status**: ✅ Ready for Programming

---

## 📋 Prerequisites

### Hardware Required
- ✅ Terasic DE10-Nano development board
- ✅ USB cable (Type A to Micro-B) for JTAG programming
- ✅ 5V power supply for DE10-Nano
- ✅ Host computer (Linux/Windows/Mac)

### Software Required
- ✅ Intel Quartus Prime Programmer (included with Quartus installation)
- ✅ USB Blaster II driver installed
- ✅ Programming file: `ads_bus_system.sof` (6.4 MB)

### File Location
```
/home/prabathbk/ads_bus/da-bus/Serial/quartus/ads_bus_system.sof
```

---

## 🔌 Hardware Setup

### Step 1: Connect Power
1. Connect 5V power supply to DE10-Nano barrel jack
2. Verify **PWR** LED illuminates (green)

### Step 2: Connect JTAG
1. Connect USB cable from PC to DE10-Nano USB Blaster II port
2. Wait for USB device enumeration (~5 seconds)
3. Verify driver installation (Linux: automatic, Windows: may require driver)

### Step 3: Board Configuration
1. Ensure **MSEL[4:0]** switches are in default position (JTAG mode)
2. No additional configuration required for .sof programming

---

## 💻 Programming Methods

### Method 1: Command Line (Recommended)

**Single Command**:
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus
quartus_pgm -m jtag -o "p;ads_bus_system.sof@1"
```

**Expected Output**:
```
Info (213045): Using programming cable "USB-Blaster [USB-0]"
Info (213011): Using programming file ads_bus_system.sof with checksum 0x00123456
Info (209060): Started Programmer operation at Mon Oct 14 18:00:00 2025
Info (209016): Configuring device index 1
Info (209017): Device 1 contains JTAG ID code 0x02D020DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info (209011): Successfully performed operation(s)
Info (209061): Ended Programmer operation at Mon Oct 14 18:00:15 2025
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

**Duration**: 10-15 seconds

---

### Method 2: Quartus GUI

**Steps**:
1. Launch Quartus Programmer:
   ```bash
   quartus_pgmw &
   ```

2. **Hardware Setup**:
   - Click "Hardware Setup..."
   - Select "USB-Blaster [USB-0]"
   - Click "Close"

3. **Add Programming File**:
   - Click "Add File..."
   - Navigate to: `/home/prabathbk/ads_bus/da-bus/Serial/quartus/`
   - Select: `ads_bus_system.sof`
   - Click "Open"

4. **Configure Programming**:
   - Check "Program/Configure" box for ads_bus_system.sof
   - Mode should be: JTAG
   - Device: 5CSEBA6U23I7

5. **Program**:
   - Click "Start"
   - Watch progress bar (10-15 seconds)
   - Wait for "100% (Successful)" message

---

### Method 3: Automation Script

**Create programming script** (`program_fpga.sh`):
```bash
#!/bin/bash
# ADS Bus System - FPGA Programming Script

QUARTUS_DIR="/home/prabathbk/ads_bus/da-bus/Serial/quartus"
SOF_FILE="ads_bus_system.sof"

cd "$QUARTUS_DIR" || exit 1

echo "=========================================="
echo "ADS Bus System - FPGA Programmer"
echo "=========================================="
echo ""
echo "Programming file: $SOF_FILE"
echo "Target: DE10-Nano (5CSEBA6U23I7)"
echo ""

# Check if .sof file exists
if [ ! -f "$SOF_FILE" ]; then
    echo "ERROR: Programming file not found!"
    echo "Expected: $QUARTUS_DIR/$SOF_FILE"
    exit 1
fi

echo "File size: $(du -h $SOF_FILE | cut -f1)"
echo ""

# Check if Quartus Programmer is available
if ! command -v quartus_pgm &> /dev/null; then
    echo "ERROR: quartus_pgm not found!"
    echo "Please install Quartus Prime and add to PATH"
    exit 1
fi

# Detect JTAG cable
echo "Detecting JTAG cable..."
quartus_pgm -l | grep -i "blaster"
if [ $? -ne 0 ]; then
    echo "WARNING: USB Blaster not detected!"
    echo "Please check USB connection and driver installation"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Starting FPGA programming..."
echo "This will take approximately 10-15 seconds..."
echo ""

# Program FPGA
quartus_pgm -m jtag -o "p;$SOF_FILE@1"

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ PROGRAMMING SUCCESSFUL!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Check LED[0] - should be ON (system active)"
    echo "2. Observe other LEDs for bus activity"
    echo "3. Connect external masters to GPIO if needed"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ PROGRAMMING FAILED!"
    echo "=========================================="
    echo ""
    echo "Troubleshooting:"
    echo "1. Check USB cable connection"
    echo "2. Verify power supply is connected"
    echo "3. Check JTAG driver installation"
    echo "4. Try: quartus_pgm -l  (list JTAG devices)"
    echo ""
    exit 1
fi
```

**Usage**:
```bash
chmod +x program_fpga.sh
./program_fpga.sh
```

---

## 🔍 Verification After Programming

### LED Status Check

Immediately after programming, verify the following LED states:

| LED | Function | Expected State | Meaning |
|-----|----------|----------------|---------|
| **LED[0]** | System Active | ✅ **ON** (solid) | Reset de-asserted, clock running |
| **LED[1]** | M1 HBUSREQ | OFF or flashing | Master 1 bus request |
| **LED[2]** | M2 HBUSREQ | OFF or flashing | Master 2 bus request |
| **LED[3]** | M1 HACK | OFF or pulsing | Master 1 acknowledge |
| **LED[4]** | M2 HACK | OFF or pulsing | Master 2 acknowledge |
| **LED[5]** | M1 SPLIT | OFF | Master 1 split transaction |
| **LED[6]** | M2 SPLIT | OFF | Master 2 split transaction |
| **LED[7]** | Reserved | OFF | (not used) |

**✅ Success Indicator**: LED[0] solid ON

**❌ Failure Indicators**:
- All LEDs OFF → Programming failed or power issue
- Random LED pattern → Clock not running properly
- LED[0] OFF → Reset stuck asserted

### Basic Functionality Test

**Without External Masters** (Test Pattern Generator Active):

The top-level module includes a test pattern generator that creates activity:

```verilog
// Internal test pattern (when GPIO not driven)
assign internal_test = ~reset_n;  // Active after reset
```

**Expected Behavior**:
- LED[1-2]: Should show brief activity during initialization
- LED[0]: Always ON after ~1 second
- Other LEDs: May flash briefly during startup

**With External Masters** (GPIO Connected):

Connect test logic to Arduino headers and drive transactions:
- Monitor LED[1-6] for bus activity
- LED[0] remains ON throughout operation

---

## 🔧 Troubleshooting

### Issue 1: "No JTAG cable detected"

**Symptoms**:
```
Error (213013): Programming hardware cable not detected
```

**Solutions**:
1. **Check USB Connection**:
   ```bash
   lsusb | grep -i altera
   # Should show: Bus 001 Device 005: ID 09fb:6010 Altera
   ```

2. **Install/Update Driver** (Linux):
   ```bash
   # Quartus USB Blaster udev rules
   sudo cp /opt/intelFPGA/20.1/quartus/linux64/pgm_parts.txt /etc/udev/rules.d/51-usbblaster.rules
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

3. **Verify Device Permissions**:
   ```bash
   ls -l /dev/bus/usb/*/*
   # Add user to dialout group if needed
   sudo usermod -a -G dialout $USER
   ```

4. **Test JTAG Chain**:
   ```bash
   quartus_pgm -l  # List detected cables
   quartus_pgm -c 1 -a  # Auto-detect chain
   ```

---

### Issue 2: "Configuration failed"

**Symptoms**:
```
Error (209012): Operation failed
```

**Solutions**:

1. **Verify .sof File**:
   ```bash
   ls -lh quartus/ads_bus_system.sof
   # Should be ~6.4 MB
   file quartus/ads_bus_system.sof
   # Should show: data
   ```

2. **Check Device ID**:
   ```bash
   quartus_pgm -c 1 -a
   # Should detect: 5CSEBA6U23I7 (0x02D020DD)
   ```

3. **Try Lower JTAG Clock**:
   ```bash
   quartus_pgm -m jtag -c 1 --frequency=6M -o "p;ads_bus_system.sof@1"
   ```

4. **Power Cycle Board**:
   - Disconnect power
   - Wait 5 seconds
   - Reconnect power
   - Retry programming

---

### Issue 3: "LED[0] stays OFF after programming"

**Symptoms**:
- Programming reports success
- But LED[0] remains OFF

**Solutions**:

1. **Check Reset Button** (KEY0):
   - Press and release KEY0 button
   - LED[0] should turn ON when released

2. **Verify Clock Input**:
   - 50 MHz clock should be present on FPGA_CLK1_50 (PIN_V11)
   - Check board oscillator is populated

3. **Re-program FPGA**:
   ```bash
   quartus_pgm -m jtag -o "p;ads_bus_system.sof@1"
   ```

---

### Issue 4: "Windows driver installation"

**Windows-Specific Steps**:

1. **Download Driver**:
   - From Quartus installation: `<quartus_install>/drivers/usb-blaster-ii`

2. **Manual Driver Install**:
   - Device Manager → Unknown Device → Update Driver
   - Browse to driver folder
   - Select USB-Blaster II driver

3. **Verify Installation**:
   - Device Manager should show "Altera USB-Blaster II"
   - No yellow exclamation marks

---

## 📊 Post-Programming Analysis

### Verify Timing (Optional)

**Check Fmax in timing report**:
```bash
grep -i "fmax" quartus/ads_bus_system.sta.rpt
```

**Expected**: Fmax > 81 MHz

### Verify Resource Usage

**Check resource utilization**:
```bash
grep -A 10 "Fitter Resource Usage Summary" quartus/ads_bus_system.fit.rpt
```

**Expected**:
- ALMs: 408 / 41,910 (< 1%)
- M10K Blocks: 10 / 553 (1.8%)
- Registers: 428

### Verify Pin Assignments

**List all pin connections**:
```bash
grep "Location" quartus/ads_bus_system.pin | grep -v "^;"
```

**Expected**: 28 pins assigned (1 clock, 1 reset, 8 LEDs, 18 GPIO)

---

## 🚀 Next Steps After Programming

### 1. Basic Verification Complete
- ✅ FPGA programmed
- ✅ LED[0] ON
- ✅ System operational

### 2. Connect External Masters (Optional)

**Hardware Interface**:
- Refer to: `pin_assignments/DE10_Nano_Pin_Assignments.md`
- Master 1: Arduino header GPIO_M1_* (9 signals)
- Master 2: Arduino header GPIO_M2_* (9 signals)

**Signal Mapping**:
```
Master Interface (9 signals per master):
- HBUSREQ  (out) → Request bus
- HGRANT   (in)  → Bus granted
- HADDR[15:0] (out) → Address (serialized)
- HWRITE   (out) → Write enable
- HWDATA   (out) → Write data
- HLOCK    (out) → Locked transaction
- HRDATA   (in)  → Read data
- HACK     (in)  → Acknowledge
- HSPLIT   (in)  → Split transaction
```

### 3. Run Hardware Tests

**Test Sequence**:
1. Drive HBUSREQ high
2. Wait for HGRANT (LED should show activity)
3. Send address (16 serial bits, LSB first)
4. Send data/control signals
5. Wait for HACK
6. Read HRDATA response

### 4. Monitor with SignalTap (Advanced)

**Add logic analyzer**:
1. Open Quartus project
2. Tools → SignalTap II
3. Add internal signals to monitor
4. Recompile and re-program
5. Capture live waveforms

---

## 📁 File References

### Programming Files
- **SRAM Config**: `quartus/ads_bus_system.sof` (6.4 MB)
- **Checksum**: Verify in .sof file header

### Documentation
- **Full Documentation**: `docs/ADS_Bus_System_Documentation.md`
- **Pin Assignments**: `pin_assignments/DE10_Nano_Pin_Assignments.md`
- **Quick Reference**: `docs/Quick_Reference.md`
- **Status Report**: `docs/Final_Status_Report.md`

### Reports
- **Synthesis**: `quartus/ads_bus_system.map.rpt`
- **Fitter**: `quartus/ads_bus_system.fit.rpt`
- **Timing**: `quartus/ads_bus_system.sta.rpt`
- **Assembly**: `quartus/ads_bus_system.asm.rpt`

---

## ✅ Programming Checklist

Before programming:
- [ ] DE10-Nano powered on (PWR LED lit)
- [ ] USB cable connected (JTAG)
- [ ] USB Blaster driver installed
- [ ] .sof file exists (6.4 MB)
- [ ] Quartus Programmer accessible

During programming:
- [ ] Command executed without errors
- [ ] Progress: "100% Successful"
- [ ] Duration: ~10-15 seconds

After programming:
- [ ] LED[0] solid ON
- [ ] Other LEDs show activity (optional)
- [ ] No error messages in console
- [ ] System responsive

---

## 📞 Support

### Common Issues
- JTAG detection: Check USB cable and driver
- Programming failure: Power cycle board
- LED[0] OFF: Press/release KEY0 button
- No activity: Verify clock source (50 MHz)

### Additional Resources
- **DE10-Nano User Manual**: [Terasic Website](https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=1046&Lang=English)
- **Quartus Programming Guide**: Included with Quartus installation
- **USB Blaster Documentation**: Intel FPGA website

---

**Document Version**: 1.0  
**Last Updated**: October 14, 2025  
**Status**: ✅ Ready for deployment

---

**END OF PROGRAMMING GUIDE**
