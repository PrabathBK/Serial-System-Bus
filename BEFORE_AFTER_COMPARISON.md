# Before vs After Comparison

## Architecture Comparison

### BEFORE (Original demo_uart_bridge.v)
```
┌─────────────────────────────────────────────────┐
│         External UART Command Source            │
└────────────────┬────────────────────────────────┘
                 │ UART (GPIO)
                 ▼
┌────────────────────────────────────────────────┐
│           demo_uart_bridge.v                   │
│                                                │
│  Master 1 (Local)      Master 2 (UART Bridge) │
│    ▲                        ▲                  │
│    │                        │                  │
│  Buttons              UART Commands            │
│                                                │
│         ╔══════════════╗                       │
│         ║   ARBITER    ║                       │
│         ╚══════════════╝                       │
│                │                               │
│        ┌───────┴────────┐                      │
│        ▼                ▼                      │
│    Slave 1          Slave 2                    │
└────────────────────────────────────────────────┘

Issue: Cannot trigger both masters simultaneously
```

### AFTER (Modified for Priority Demo)
```
┌────────────────────────────────────────────────┐
│         KEY[0] Pressed (Single Button)         │
└─────────────┬──────────────┬───────────────────┘
              │              │
              ▼              ▼
┌────────────────────────────────────────────────┐
│           demo_uart_bridge.v                   │
│                                                │
│  Master 1 (Local)      Master 2 (Local)        │
│   FSM: WRITE            FSM: READ              │
│   Priority: HIGH        Priority: LOW          │
│                                                │
│         ╔══════════════╗                       │
│         ║   ARBITER    ║ ← Resolves conflict! │
│         ╚══════════════╝                       │
│                │                               │
│        ┌───────┴────────┐                      │
│        ▼                ▼                      │
│    Slave 1 (0x0020) Slave 2                    │
│    ▲           ▲                               │
│    │           │                               │
│    Write       Read (waits for M1)             │
└────────────────────────────────────────────────┘

Solution: Both masters triggered simultaneously!
          Arbiter grants to Master 1 first (priority)
          LEDs show the priority in action
```

## Control Interface Comparison

### BEFORE
| Control | Function |
|---------|----------|
| KEY[0] | Initiate Master 1 transaction |
| KEY[1] | Increment data OR address |
| SW[0] | Reset |
| SW[1] | Mode select (data/address) |
| SW[2] | Bus mode (internal/external) |
| SW[3] | Read/Write select |

Complex: Many modes, difficult to show priority

### AFTER  
| Control | Function |
|---------|----------|
| KEY[0] | **Trigger BOTH masters simultaneously** |
| KEY[1] | Increment data value |
| SW[0] | Reset |
| SW[1-3] | Unused |

Simple: Focus on priority demonstration

## LED Display Comparison

### BEFORE
```
LED[7:4] = Address offset
LED[3:0] = Data value or read result
```
Shows transaction data, but not priority behavior

### AFTER
```
LED[7:4] = Data value to write
LED[3]   = Master 1 active     ◄─┐
LED[2]   = Master 2 active     ◄─┤ Shows which master
LED[1]   = Master 1 bus grant  ◄─┤ is active and who
LED[0]   = Master 2 bus grant  ◄─┘ has bus access
```
**Clearly visualizes priority arbitration!**

## Code Changes Summary

### Key Additions
1. **Master 2 FSM**: New FSM for local control (replaces UART bridge)
2. **Fixed address**: `FIXED_DEMO_ADDR = 0x0020`
3. **Simultaneous trigger**: Both FSMs respond to `key0_pressed`
4. **LED mapping**: Bus grant signals connected to LEDs

### Key Removals
1. **Switch decoding**: Removed mode selection logic
2. **Address generation**: Simplified to fixed address
3. **UART bridge for M2**: Master 2 now uses `master_port`

## Expected Demo Output

### Timeline when KEY[0] pressed:

```
Time    | Master 1        | Master 2        | LEDs
--------|-----------------|-----------------|------------------
t=0     | IDLE           | IDLE            | All OFF
t=1     | Request bus    | Request bus     | LED[3]=ON, LED[2]=ON
t=2     | Bus granted!   | Waiting...      | LED[1]=ON (M1 wins!)
t=3     | Writing 0x0020 | Still waiting   | LED[1]=ON
t=4     | Complete       | Still waiting   | LED[1]=OFF, LED[3]=OFF
t=5     | IDLE           | Bus granted!    | LED[0]=ON (M2 now)
t=6     | IDLE           | Reading 0x0020  | LED[0]=ON
t=7     | IDLE           | Complete        | LED[0]=OFF, LED[2]=OFF
t=8     | IDLE           | IDLE            | All OFF
```

**Key Observation**: LED[1] lights up BEFORE LED[0], proving Master 1 priority!

## Why This Demonstrates Priority

1. **Simultaneous Request**: Both masters request bus at exactly the same time
2. **Arbiter Decision**: Arbiter must choose - it picks Master 1 (higher priority)
3. **Visual Proof**: LED[1] (M1 grant) ON before LED[0] (M2 grant)
4. **Sequential Access**: M2 must wait until M1 completes
5. **Same Address**: Both target 0x0020, creating real contention

This is a **textbook demonstration** of priority-based bus arbitration!
