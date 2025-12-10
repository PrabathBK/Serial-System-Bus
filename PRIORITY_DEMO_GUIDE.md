# Priority Demonstration Guide

## Overview
This document describes the modified `demo_uart_bridge.v` design that demonstrates Master 1's priority over Master 2 in the ADS Bus System.

## Architecture Changes

### Original Design
- **Master 1**: Local master controlled by buttons/switches
- **Master 2**: UART Bridge Master (receives commands externally)

### Modified Design (Priority Demo)
- **Master 1**: Local master (higher priority) - performs WRITE operations
- **Master 2**: Local master (lower priority) - performs READ operations
- Both masters target the **same fixed address (0x0020)** in Slave 1

## Key Modifications

### 1. Simplified Control Interface
- **KEY[0]**: Triggers BOTH Master 1 and Master 2 simultaneously
- **KEY[1]**: Increments the data value that Master 1 will write
- **SW[0]**: Reset (active high)
- **SW[1-3]**: Unused (simplified for demo)

### 2. Master 2 Conversion
Master 2 has been changed from a UART Bridge Master to a simple local master:
- Removed UART interface dependency
- Added device interface (similar to Master 1)
- Uses `master_port` module instead of `bus_bridge_master`

### 3. Fixed Address Demo
Both masters target the same address:
```verilog
localparam [15:0] FIXED_DEMO_ADDR = 16'h0020;  // Slave 1, address 0x020
```

### 4. Simultaneous Transaction Trigger
When KEY[0] is pressed:
- Master 1 FSM starts a WRITE transaction
- Master 2 FSM starts a READ transaction
- Both request bus access at the same time
- Arbiter grants bus to Master 1 first (higher priority)
- Master 2 waits and gets bus after Master 1 completes

### 5. LED Display for Priority Visualization
```
LED[7:4] - Current data value (Master 1 will write this)
LED[3]   - Master 1 transaction active (high when M1 is busy)
LED[2]   - Master 2 transaction active (high when M2 is busy)
LED[1]   - Master 1 has bus grant (shows M1 priority)
LED[0]   - Master 2 has bus grant (lights up after M1)
```

## Operation Sequence

### Step 1: Initial State
- All LEDs off
- Both masters idle
- Data value = 0x00

### Step 2: Increment Data (Optional)
- Press KEY[1] multiple times
- LED[7:4] shows incrementing data value
- This is the value Master 1 will write

### Step 3: Trigger Priority Demo
- Press KEY[0]
- **Simultaneously:**
  - Master 1 requests to WRITE data to 0x0020
  - Master 2 requests to READ data from 0x0020

### Step 4: Observe Priority
You should see the following LED sequence:

1. **LED[3] and LED[2] turn ON** (both masters requesting bus)
2. **LED[1] turns ON** (Master 1 gets bus grant - higher priority!)
3. Master 1 completes WRITE operation
4. **LED[1] turns OFF, LED[3] turns OFF**
5. **LED[0] turns ON** (Master 2 now gets bus grant)
6. Master 2 completes READ operation
7. **LED[0] turns OFF, LED[2] turns OFF**

This demonstrates that the arbiter correctly prioritizes Master 1 over Master 2.

## Hardware Connections (DE0-Nano)

### Required
- KEY[0] - Push button for triggering both masters
- KEY[1] - Push button for incrementing data
- SW[0] - Slide switch for reset
- LED[7:0] - Status display

### Unused
- SW[1-3] - Not used in priority demo mode
- GPIO pins (UART) - Not used (Master 2 is now local)

## Testing Procedure

### Test 1: Basic Priority
1. Reset the system (SW[0] = HIGH, then LOW)
2. Press KEY[0] once
3. Observe LED[1] lights before LED[0]
4. Confirms Master 1 priority

### Test 2: Different Data Values
1. Press KEY[1] several times (watch LED[7:4] increment)
2. Press KEY[0]
3. Master 1 writes the new value
4. Master 2 reads it back
5. Verify priority still holds

### Test 3: Rapid Triggering
1. Press KEY[0] multiple times rapidly
2. Observe consistent priority behavior
3. Master 1 should always get bus first

## Design Files Modified

- `rtl/demo_uart_bridge.v` - Main demo wrapper (extensively modified)

## Design Files Unchanged

- `rtl/core/master_port.v` - Master port interface
- `rtl/core/arbiter.v` - Priority arbiter (Master 1 > Master 2)
- `rtl/core/slave.v` - Slave memory modules
- `rtl/core/bus_m2_s3.v` - Bus interconnect

## Arbiter Priority Configuration

The arbiter in `bus_m2_s3.v` is configured with:
- **Master 1**: Priority 0 (highest)
- **Master 2**: Priority 1 (lower)

This ensures Master 1 always wins when both request simultaneously.

## Simulation

To simulate this design:
```bash
cd sim
./run_priority_demo_test.sh  # (Create this test script)
```

The testbench should:
1. Assert dvalid for both masters on the same clock cycle
2. Verify Master 1 gets bgrant first
3. Verify Master 2 gets bgrant after Master 1 completes

## Synthesis Notes

When synthesizing for hardware:
- Set `DEBOUNCE_COUNT = 50000` for 1ms debounce at 50MHz
- For simulation, use smaller value (e.g., 10)
- Ensure Quartus project includes all core modules

## Conclusion

This modified design clearly demonstrates the priority arbitration mechanism in the ADS Bus System. By triggering both masters simultaneously and observing the LED indicators, users can visually confirm that Master 1 has priority over Master 2 when competing for bus access.
