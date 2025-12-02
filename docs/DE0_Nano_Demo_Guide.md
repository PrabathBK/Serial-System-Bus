# ADS Bus System Demo - DE0-Nano Guide

## Target Board
**Terasic DE0-Nano** (Intel Cyclone IV EP4CE22F17C6)

---

## Interactive Demo Controls

### Push Buttons
| Button | Function |
|--------|----------|
| **KEY[0]** | Trigger transaction (press to send) |
| **KEY[1]** | Increment data pattern (+1 each press) |

### DIP Switches
| Switch | Function |
|--------|----------|
| **SW[0]** | Reset (HIGH = reset active, LOW = run) |
| **SW[1]** | Master select: 0 = Master 1, 1 = Master 2 |
| **SW[3:2]** | Slave & Mode select (see table below) |

### Slave/Mode Selection (directly directly directly directly directly directly directly directly directly directly SW[3:2])
| SW[3:2] | Slave | Operation |
|---------|-------|-----------|
| **00** | Slave 1 (2KB) | Write |
| **01** | Slave 2 (4KB) | Write |
| **10** | Slave 3 (4KB, SPLIT) | Write |
| **11** | Slave 1 | Read (read back data) |

---

## LED Display

| LED | Function |
|-----|----------|
| **LED[1:0]** | Slave number (binary: 00=S1, 01=S2, 10=S3) |
| **LED[7:2]** | Last 6 bits of data sent/received |

### Example LED Patterns

| Data | Slave | LED[7:0] Pattern |
|------|-------|------------------|
| 0xA5 (10100101) | Slave 1 (00) | `100101_00` |
| 0xB6 (10110110) | Slave 2 (01) | `110110_01` |
| 0xC7 (11000111) | Slave 3 (10) | `000111_10` |

---

## Demo Walkthrough

### Basic Write/Read Test

1. **Power on** the DE0-Nano
2. **Set SW[0] = LOW** for normal operation
3. **Set switches for write to Slave 1**:
   - SW[1] = 0 (Master 1)
   - SW[3:2] = 00 (Slave 1, Write)
4. **Press KEY[0]** to trigger write transaction
5. **Observe LEDs**: Should show `100101_00` (data 0xA5 to Slave 1)
6. **Change to read mode**: Set SW[3:2] = 11 (Read from Slave 1)
7. **Press KEY[0]** to read back
8. **Observe LEDs**: Should show same data pattern read back

### Multi-Master Test

1. **Write with Master 1**:
   - SW[1] = 0, SW[3:2] = 01 (Master 1 → Slave 2)
   - Press KEY[0]
2. **Write with Master 2**:
   - SW[1] = 1, SW[3:2] = 01 (Master 2 → Slave 2)
   - Press KEY[1] to change data pattern
   - Press KEY[0]
3. Compare LED outputs to verify both masters work

### Data Pattern Increment

- Initial data: **0x00**
- Press KEY[1] once: **0x01** (+1)
- Press KEY[1] again: **0x02** (+1)
- And so on... (wraps at 0xFF → 0x00)

---

## Memory Map

| Slave | Device Address | Memory Size | Features |
|-------|----------------|-------------|----------|
| Slave 1 | 2'b00 | 2KB | Basic |
| Slave 2 | 2'b01 | 4KB | Basic |
| Slave 3 | 2'b10 | 4KB | SPLIT transaction support |

---

## Pin Assignments Summary

| Signal | DE0-Nano Pin | Description |
|--------|--------------|-------------|
| CLOCK_50 | PIN_R8 | 50 MHz oscillator |
| KEY[0] | PIN_J15 | Transaction trigger |
| KEY[1] | PIN_E1 | Data increment |
| SW[0] | PIN_M1 | Reset switch |
| SW[1] | PIN_T8 | Master select |
| SW[2] | PIN_B9 | Slave select [0] |
| SW[3] | PIN_M15 | Slave select [1] / Read mode |
| LED[0] | PIN_A15 | Slave select LSB |
| LED[1] | PIN_A13 | Slave select MSB |
| LED[2-7] | Various | Data bits [0-5] |

---

## Quick Reference Card

```
╔═══════════════════════════════════════════════════════╗
║            DE0-Nano ADS Bus Demo                      ║
╠═══════════════════════════════════════════════════════╣
║  SW[0]: Reset    SW[1]: Master (0=M1, 1=M2)           ║
║  SW[3:2]: 00=S1/W  01=S2/W  10=S3/W  11=S1/Read       ║
╠═══════════════════════════════════════════════════════╣
║  KEY[0]: Send Transaction    KEY[1]: Change Data      ║
╠═══════════════════════════════════════════════════════╣
║  LED[1:0]: Slave#    LED[7:2]: Data (lower 6 bits)    ║
╚═══════════════════════════════════════════════════════╝
```
