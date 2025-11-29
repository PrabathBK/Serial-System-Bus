# ADS Bus System - Quartus Synthesis Quick Start

## ⚡ Quick Synthesis (3 Minutes)

**Prerequisites**: Intel Quartus Prime Lite 20.1+ installed

### Option 1: Automated Script ✨ (Recommended)
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial
./scripts/synthesize_and_verify.sh
```

### Option 2: Single Command
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus
quartus_sh --flow compile ads_bus_system
```

### Option 3: GUI
```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus
quartus ads_bus_system.qpf
# Then: Processing → Start Compilation (Ctrl+L)
```

---

## 📦 Install Quartus (If Needed)

**Download**: [Intel Quartus Prime Lite Edition](https://www.intel.com/content/www/us/en/software-kit/665990/intel-quartus-prime-lite-edition-design-software-version-20-1-for-linux.html)

```bash
# Extract and install
chmod +x QuartusLiteSetup-20.1.1.720-linux.run
./QuartusLiteSetup-20.1.1.720-linux.run

# Add to PATH
export PATH=/opt/intelFPGA/20.1/quartus/bin:$PATH
```

---

## ✅ Expected Results

- **Duration**: 3-5 minutes
- **Output**: `quartus/output_files/ads_bus_system.sof`
- **Resources**: <2% ALMs, 1.8% M10K (10 blocks)
- **Timing**: Fmax ~80-100 MHz (target: 50 MHz)
- **Status**: 0 errors expected

---

## 🔌 Program FPGA

```bash
cd /home/prabathbk/ads_bus/da-bus/Serial/quartus/output_files
quartus_pgm -m jtag -o "p;ads_bus_system.sof@1"
```

**Verify**: LED[0] should turn ON after programming

---

## 📚 Documentation

- **Full Guide**: `docs/Synthesis_Instructions.md`
- **System Docs**: `docs/ADS_Bus_System_Documentation.md`
- **Quick Ref**: `docs/Quick_Reference.md`
- **Status**: `docs/Final_Status_Report.md`

---

## 🎯 Project Status

✅ **9/10 Tasks Complete**
- ✅ RTL Design (11 modules)
- ✅ Verification (77/77 tests passed)
- ✅ Quartus Project Setup
- ✅ Documentation
- ⏳ **Synthesis** ← Run commands above

---

## 🚨 Troubleshooting

**"quartus_sh: command not found"**
→ Install Quartus and add to PATH (see above)

**"Timing not met"**
→ Unlikely at 50 MHz; check `output_files/ads_bus_system.sta.rpt`

**"Memory not inferred"**
→ Check for M10K blocks in `output_files/ads_bus_system.map.rpt`

---

**Target**: Intel Cyclone V 5CSEBA6U23I7 (Terasic DE10-Nano)  
**Date**: October 14, 2025
