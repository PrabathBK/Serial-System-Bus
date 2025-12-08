# UART Bridge Demo Test Guide

## Overview

This guide explains how to test the `demo_uart_bridge.v` module on DE0-Nano FPGAs. The demo supports both **internal** (local bus) and **external** (UART bridge) communication modes.

---

## Hardware Setup

### Single FPGA Testing (Internal Mode)
- 1x DE0-Nano FPGA board
- USB cable for programming and power

### Dual FPGA Testing (External/Bridge Mode)
- 2x DE0-Nano FPGA boards
- 4x jumper wires for UART connections
- Common ground connection

### Pin Connections for Dual FPGA

| FPGA A (Sender)         | Wire | FPGA B (Receiver)       |
|-------------------------|------|-------------------------|
| GPIO_0_BRIDGE_S_TX (B8) | →    | GPIO_0_BRIDGE_M_RX (D3) |
| GPIO_0_BRIDGE_S_RX (C3) | ←    | GPIO_0_BRIDGE_M_TX (A8) |
| GND                     | ─    | GND                     |

```
FPGA A (Sender)                          FPGA B (Receiver)
┌─────────────────┐                      ┌─────────────────┐
│                 │                      │                 │
│  Bridge Slave   │                      │  Bridge Master  │
│  (Slave 3)      │                      │  (Master 2)     │
│                 │                      │                 │
│  S_TX (PIN_B8) ─┼──────────────────────┼→ M_RX (PIN_D3)  │
│  S_RX (PIN_C3) ←┼──────────────────────┼─ M_TX (PIN_A8)  │
│                 │                      │                 │
│       GND ──────┼──────────────────────┼─ GND            │
└─────────────────┘                      └─────────────────┘
```

---

## Control Interface

### Push Buttons

| Button | Function |
|--------|----------|
| KEY[0] | Trigger transaction (press to send data) |
| KEY[1] | Increment data pattern (+1 each press) |

### DIP Switches

| Switch | Function |
|--------|----------|
| SW[0]  | Reset (HIGH = reset active, LOW = normal operation) |
| SW[1]  | Internal slave select (0 = Slave 1, 1 = Slave 2) |
| SW[2]  | External/Remote slave select (0 = Remote S1, 1 = Remote S2) |
| SW[3]  | Mode select (0 = Internal, 1 = External via UART Bridge) |

### LED Indicators

| LED | Meaning |
|-----|---------|
| LED[0] | Transaction active (blinks during transmission) |
| LED[1] | Mode indicator (OFF = Internal, ON = External) |
| LED[7:2] | Data pattern (lower 6 bits) |

---

## Operation Modes

### Mode 1: Internal (SW[3] = 0)

In this mode, the local Master 1 communicates directly with internal slaves (Slave 1 or Slave 2).

| SW[3] | SW[1] | Target | Description |
|-------|-------|--------|-------------|
| 0     | 0     | Slave 1 | Write to local 2KB memory |
| 0     | 1     | Slave 2 | Write to local 4KB memory |

**Note:** SW[2] is ignored in Internal mode.

### Mode 2: External/Bridge (SW[3] = 1)

In this mode, the local Master 1 sends data through the Bridge Slave (Slave 3) via UART to a remote FPGA.

| SW[3] | SW[2] | Target | Description |
|-------|-------|--------|-------------|
| 1     | 0     | Remote Slave 1 | Write to remote FPGA's Slave 1 |
| 1     | 1     | Remote Slave 2 | Write to remote FPGA's Slave 2 |

**Note:** SW[1] is ignored in External mode.

---

## Test Procedures

### Test 1: Internal Mode - Write to Slave 1

1. **Setup:**
   - Program FPGA with `demo_uart_bridge.v`
   - Set SW[3:0] = `0000` (Reset off, Internal mode, Slave 1)

2. **Execute:**
   - Press KEY[0] to trigger transaction
   - Observe LED[0] blink briefly (transaction active)

3. **Verify:**
   - LED[1] = OFF (Internal mode)
   - LED[7:2] shows data pattern (initially 000000)

4. **Increment and repeat:**
   - Press KEY[1] to increment data pattern
   - Press KEY[0] to send again
   - LED[7:2] should show 000001

---

### Test 2: Internal Mode - Write to Slave 2

1. **Setup:**
   - Set SW[3:0] = `0010` (Reset off, Internal mode, Slave 2)

2. **Execute:**
   - Press KEY[1] a few times to set data pattern
   - Press KEY[0] to send

3. **Verify:**
   - LED[1] = OFF (Internal mode)
   - LED[7:2] shows the data pattern

---

### Test 3: External Mode - Single FPGA (Loopback)

For testing external mode without a second FPGA, you can connect the bridge TX to RX for loopback:

1. **Setup:**
   - Connect PIN_B8 (S_TX) to PIN_D3 (M_RX) with a jumper wire
   - Set SW[3:0] = `1000` (External mode, Remote Slave 1)

2. **Execute:**
   - Press KEY[0] to trigger transaction

3. **Verify:**
   - LED[0] blinks during UART transmission
   - LED[1] = ON (External mode)
   - Data is transmitted via UART and received back by Bridge Master

---

### Test 4: External Mode - Dual FPGA Communication

1. **FPGA A (Sender) Setup:**
   - Program with `demo_uart_bridge.v`
   - Set SW[3:0] = `1000` (External mode, Remote Slave 1)

2. **FPGA B (Receiver) Setup:**
   - Program with `demo_uart_bridge.v`
   - Set SW[3:0] = `0000` (Internal mode - Bridge Master is always active)

3. **Wire Connections:**
   - Connect FPGA A GPIO_0_BRIDGE_S_TX → FPGA B GPIO_0_BRIDGE_M_RX
   - Connect FPGA A GPIO_0_BRIDGE_S_RX ← FPGA B GPIO_0_BRIDGE_M_TX
   - Connect GND between both boards

4. **Execute on FPGA A:**
   - Press KEY[1] to set data pattern (e.g., 5 times for pattern 000101)
   - Press KEY[0] to send via Bridge

5. **Observe on FPGA B:**
   - Data is received by Bridge Master (Master 2)
   - Data is written to FPGA B's local Slave 1

6. **Verify:**
   - FPGA A: LED[1] = ON (External mode), LED[7:2] = data pattern
   - FPGA B: Can verify data in memory via simulation or debug

---

### Test 5: External Mode - Different Remote Slave

1. **FPGA A Setup:**
   - Set SW[3:0] = `1100` (External mode, Remote Slave 2)

2. **Execute:**
   - Press KEY[1] to set data pattern
   - Press KEY[0] to send

3. **Result:**
   - Data is sent via UART to Remote FPGA's Slave 2

---

## Expected LED Patterns

| Scenario | LED[7:2] | LED[1] | LED[0] |
|----------|----------|--------|--------|
| Idle, data=0x00 | 000000 | Mode | OFF |
| Sending | Data | Mode | ON (brief) |
| After KEY[1] x3 | 000011 | Mode | OFF |
| Internal mode | Data | OFF | Activity |
| External mode | Data | ON | Activity |

---

## Troubleshooting

### No Response on KEY[0] Press
- Check SW[0] is LOW (not in reset)
- Verify FPGA is properly programmed
- Check clock source (50 MHz on DE0-Nano)

### LED[0] Stays ON
- Transaction timeout may have occurred
- Check UART connections if in external mode
- Press SW[0] briefly to reset

### External Mode - No Data Received on FPGA B
- Verify wire connections (TX→RX, RX←TX)
- Check common GND connection
- Verify baud rate settings (9600 baud)
- Check that FPGA B is not in reset

### Data Pattern Not Incrementing
- Ensure KEY[1] press is registered (button debounce)
- Check that SW[0] is LOW (reset clears pattern to 0x00)

---

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| Clock Frequency | 50 MHz |
| UART Baud Rate | 9600 bps |
| Data Width | 8 bits |
| Address Width | 16 bits |
| Slave 1 Memory | 2 KB (11-bit address) |
| Slave 2 Memory | 4 KB (12-bit address) |
| Slave 3 | Bridge Slave (UART TX) |
| Master 1 | Local (button-controlled) |
| Master 2 | Bridge Master (UART RX) |

---

## Pin Assignments (DE0-Nano)

| Signal | Pin | GPIO Connector |
|--------|-----|----------------|
| CLOCK_50 | R8 | - |
| KEY[0] | J15 | - |
| KEY[1] | E1 | - |
| SW[0] | M1 | - |
| SW[1] | T8 | - |
| SW[2] | B9 | - |
| SW[3] | M15 | - |
| LED[0] | A15 | - |
| LED[1] | A13 | - |
| LED[2] | B13 | - |
| LED[3] | A11 | - |
| LED[4] | D1 | - |
| LED[5] | F3 | - |
| LED[6] | B1 | - |
| LED[7] | L3 | - |
| GPIO_0_BRIDGE_M_TX | A8 | GPIO_0 |
| GPIO_0_BRIDGE_M_RX | D3 | GPIO_0 |
| GPIO_0_BRIDGE_S_TX | B8 | GPIO_0 |
| GPIO_0_BRIDGE_S_RX | C3 | GPIO_0 |

---

## 7 Test Cases (Matching tb_demo_uart_bridge.sv)

These test cases match the simulation testbench for hardware verification.

### Test Configuration Table

| Test | Description | SW[3] | SW[2] | SW[1] | SW[0] | FPGA |
|------|-------------|-------|-------|-------|-------|------|
| 1 | Internal Write: A:M1 → A:S1 | 0 | X | 0 | 0 | A |
| 2 | Internal Write: A:M1 → A:S2 | 0 | X | 1 | 0 | A |
| 3 | External Write: A:M1 → B:S1 | 1 | 0 | X | 0 | A |
| 4 | External Write: A:M1 → B:S2 | 1 | 1 | X | 0 | A |
| 5 | Bridge Path: A:M1 → A:S3 | 1 | 0 | X | 0 | A |
| 6 | Reverse: B:M1 → A:S1 | 1 | 0 | X | 0 | B |
| 7 | External: A:M1 → B:S3 | 1 | 1 | X | 0 | A |

**X** = Don't care (ignored in that mode)

---

### Test 1: Internal Write to Slave 1
```
FPGA A: SW[3:0] = 0000
  SW[3]=0 (Internal mode)
  SW[1]=0 (Select Slave 1)
Press KEY[1] once, then KEY[0] to trigger
Expected: LED[7:2] = 0x01, LED[1] = OFF
```

### Test 2: Internal Write to Slave 2
```
FPGA A: SW[3:0] = 0010
  SW[3]=0 (Internal mode)
  SW[1]=1 (Select Slave 2)
Press KEY[1] twice, then KEY[0] to trigger
Expected: LED[7:2] = 0x02, LED[1] = OFF
```

### Test 3: External Write to Remote S1 (via bridge)
```
FPGA A: SW[3:0] = 1000
  SW[3]=1 (External mode)
  SW[2]=0 (Remote Slave 1)
Press KEY[1] 3x, then KEY[0] to trigger
Expected: LED[7:2] = 0x03, LED[1] = ON
Data arrives at FPGA B's Slave 1
```

### Test 4: External Write to Remote S2 (via bridge)
```
FPGA A: SW[3:0] = 1100
  SW[3]=1 (External mode)
  SW[2]=1 (Remote Slave 2)
Press KEY[1] 4x, then KEY[0] to trigger
Expected: LED[7:2] = 0x04, LED[1] = ON
Data arrives at FPGA B's Slave 2
```

### Test 5: Bridge Path Test (A:M1 → A:S3)
```
FPGA A: SW[3:0] = 1000
  SW[3]=1 (External mode)
  SW[2]=0 (Remote Slave 1)
Press KEY[1] 5x, then KEY[0] to trigger
Expected: LED[7:2] = 0x05, LED[1] = ON
Tests the bridge slave path
```

### Test 6: Reverse Direction (B:M1 → A:S1)
```
FPGA B: SW[3:0] = 1000
  SW[3]=1 (External mode)
  SW[2]=0 (Remote Slave 1 on FPGA A)
Press KEY[1] 6x on FPGA B, then KEY[0]
Expected: FPGA B LED[7:2] = 0x06, LED[1] = ON
Data arrives at FPGA A's Slave 1
```

### Test 7: External Write to Remote S3
```
FPGA A: SW[3:0] = 1100
  SW[3]=1 (External mode)
  SW[2]=1 (Remote Slave 2 → routes to S3)
Press KEY[1] 7x, then KEY[0] to trigger
Expected: LED[7:2] = 0x07, LED[1] = ON
Data arrives at FPGA B's Bridge Slave (S3)
```

---

## Dual FPGA Wiring for All 7 Tests

For bidirectional communication, connect both bridge TX/RX pairs:

```
FPGA A                              FPGA B
───────────────────────────────────────────────
GPIO_0_BRIDGE_S_TX (B8)  ────────►  GPIO_0_BRIDGE_M_RX (D3)
GPIO_0_BRIDGE_M_TX (A8)  ◄────────  GPIO_0_BRIDGE_S_RX (C3)
GPIO_0_BRIDGE_M_RX (D3)  ◄────────  GPIO_0_BRIDGE_S_TX (B8)
GPIO_0_BRIDGE_S_RX (C3)  ────────►  GPIO_0_BRIDGE_M_TX (A8)
GND                      ──────────  GND
```

**Simplified (4 wires + GND):**
```
FPGA A          FPGA B
  B8  ──────────  D3    (A's Bridge Slave TX → B's Bridge Master RX)
  C3  ──────────  A8    (A's Bridge Slave RX ← B's Bridge Master TX)
  A8  ──────────  C3    (A's Bridge Master TX → B's Bridge Slave RX)
  D3  ──────────  B8    (A's Bridge Master RX ← B's Bridge Slave TX)
  GND ──────────  GND
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    UART BRIDGE DEMO                         │
├─────────────────────────────────────────────────────────────┤
│  SW[3]=0: INTERNAL MODE          SW[3]=1: EXTERNAL MODE     │
│  ├─ SW[1]=0: Slave 1             ├─ SW[2]=0: Remote S1      │
│  └─ SW[1]=1: Slave 2             └─ SW[2]=1: Remote S2      │
├─────────────────────────────────────────────────────────────┤
│  KEY[0]: Send Data               KEY[1]: Increment Data     │
├─────────────────────────────────────────────────────────────┤
│  LED[0]: TX Active    LED[1]: Ext Mode    LED[7:2]: Data    │
└─────────────────────────────────────────────────────────────┘
```

---

## Test Procedure Summary

1. **Reset**: Set SW[0]=1 briefly, then SW[0]=0
2. **Configure**: Set SW[3:1] per test table above
3. **Set Data**: Press KEY[1] N times for data pattern N
4. **Trigger**: Press KEY[0] to send transaction
5. **Verify**: 
   - LED[0] goes ON then OFF (transaction complete)
   - LED[1] shows mode (OFF=internal, ON=external)
   - LED[7:2] shows data pattern
