# Quick Start Guide - Priority Demonstration

## Hardware Setup (DE0-Nano)

1. **Program FPGA** with modified `demo_uart_bridge.v` design
2. **Connect nothing** - All demo controls are on-board!

## Controls

```
┌─────────────────────────────────────────┐
│  KEY[0]  →  Trigger Priority Demo       │
│  KEY[1]  →  Increment Write Data        │
│  SW[0]   →  Reset (slide to HIGH then LOW) │
└─────────────────────────────────────────┘
```

## LED Meaning

```
┌────────────────────────────────────────────────┐
│  LED[7:4]  →  Data Value (shown in binary)    │
│  LED[3]    →  Master 1 Active (Write)         │
│  LED[2]    →  Master 2 Active (Read)          │
│  LED[1]    →  Master 1 Has Bus (Priority!)    │
│  LED[0]    →  Master 2 Has Bus (Waits)        │
└────────────────────────────────────────────────┘
```

## Demo Steps

### Step 1: Reset
```
1. Move SW[0] to HIGH (LEDs may light up)
2. Move SW[0] to LOW (all LEDs should turn OFF)
```

### Step 2: Set Data Value (Optional)
```
1. Press KEY[1] multiple times
2. Watch LED[7:4] increment (binary counter)
3. This is the value Master 1 will write
```

### Step 3: Trigger Priority Demo
```
1. Press KEY[0] ONCE
2. Watch the LED sequence:
   
   LED[3] ON ─┐
   LED[2] ON ─┤ ← Both masters requesting!
              │
   LED[1] ON ─┤ ← Master 1 wins (priority)
              │
   LED[1] OFF ┤ ← Master 1 done
   LED[3] OFF ┤
              │
   LED[0] ON ─┤ ← Master 2 gets bus now
              │
   LED[0] OFF ┤ ← Master 2 done
   LED[2] OFF ─┘
```

### Step 4: Repeat
```
Press KEY[0] again - Same priority behavior!
```

## What You're Seeing

When you press KEY[0]:

1. **Both masters** request the bus **simultaneously**
2. **Arbiter** detects conflict and applies priority rules
3. **Master 1** (higher priority) gets bus grant first
4. **Master 1** writes data to address 0x0020
5. **Master 2** waits (lower priority)
6. After M1 completes, **Master 2** gets bus grant
7. **Master 2** reads data from address 0x0020

**Key Point**: LED[1] always lights up BEFORE LED[0]!
This proves Master 1 has higher priority.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No LEDs light up | Check SW[0] is LOW (not in reset) |
| LEDs stay on | Reset with SW[0] HIGH then LOW |
| Can't see priority | LEDs may change fast - press KEY[0] slowly |
| Wrong data value | Press KEY[1] to increment, or reset |

## Understanding the LEDs

```
Example: Write value 0x05 (binary 0101)

Before KEY[0]:
LED: 7 6 5 4   3 2 1 0
     0 1 0 1   0 0 0 0  ← Data=5, all idle

During Demo (M1 active with bus):
LED: 7 6 5 4   3 2 1 0
     0 1 0 1   1 1 1 0  ← M1 active, M2 active, M1 has bus

During Demo (M2 active with bus):
LED: 7 6 5 4   3 2 1 0
     0 1 0 1   0 1 0 1  ← M2 active, M2 has bus

After Demo:
LED: 7 6 5 4   3 2 1 0
     0 1 0 1   0 0 0 0  ← Back to idle
```

## Next Steps

- Try different data values (KEY[1])
- Press KEY[0] rapidly to see consistent priority
- Compare with arbiter.v source code to understand priority logic

## Files to Reference

- `rtl/demo_uart_bridge.v` - Main design
- `rtl/core/arbiter.v` - Priority arbitration logic
- `PRIORITY_DEMO_GUIDE.md` - Detailed documentation
- `BEFORE_AFTER_COMPARISON.md` - Architecture comparison
