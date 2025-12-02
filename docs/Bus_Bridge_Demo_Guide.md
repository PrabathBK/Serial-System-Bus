# ADS Bus System - Bus Bridge Demo Guide

## Overview

This demo showcases **inter-bus communication** using the ADS Bus System with Bus Bridge modules. Two separate bus systems can communicate with each other through UART-based bridge modules.

## Target Board
**Terasic DE0-Nano** (Intel Cyclone IV EP4CE22F17C6)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DE0-Nano FPGA (Bus A)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐                    ┌───────────────────┐              │
│  │   Master 1   │◄──────────────────►│                   │              │
│  │  (directly directly directly directly directly directly Local Demo) │          │   Bus Interconnect  │              │
│  │  KEY/SW Ctrl │                    │     (Arbiter,     │              │
│  └──────────────┘                    │   Addr Decoder)   │              │
│                                      │                   │              │
│  ┌──────────────┐                    │                   │              │
│  │   Master 2   │◄──────────────────►│                   │              │
│  │ (Bus Bridge) │                    │                   │              │
│  │   Master     │                    └─────────┬─────────┘              │
│  └──────┬───────┘                              │                        │
│         │ UART                    ┌────────────┼────────────┐           │
│         │                         │            │            │           │
│         ▼                         ▼            ▼            ▼           │
│  ┌──────────────┐          ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  GPIO_0_     │          │ Slave 1  │ │ Slave 2  │ │   Slave 3    │   │
│  │  BRIDGE_M_   │          │  (2KB)   │ │  (4KB)   │ │ (Bus Bridge) │   │
│  │  TX/RX       │          │  Local   │ │  Local   │ │    Slave     │   │
│  └──────────────┘          └──────────┘ └──────────┘ └──────┬───────┘   │
│         │                                                    │ UART     │
│         │                                                    ▼          │
│         │                                             ┌──────────────┐  │
│         │                                             │  GPIO_0_     │  │
│         │                                             │  BRIDGE_S_   │  │
│         │                                             │  TX/RX       │  │
│         │                                             └──────────────┘  │
└─────────┼───────────────────────────────────────────────────┼───────────┘
          │                                                   │
          │              UART Connection                      │
          │         (To External Bus System)                  │
          ▼                                                   ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                    External Bus System (Bus B)                  │
    │                (Another DE0-Nano or other device)               │
    └─────────────────────────────────────────────────────────────────┘
```

---

## Components

### Master 1: Local Demo Master
- Controlled by KEY[0] (trigger), KEY[1] (data increment), and SW switches
- Can write to Slave 1, Slave 2, or Slave 3 (Bridge)

### Master 2: Bus Bridge Master
- Receives commands via UART from an external bus system
- Executes those commands on the local bus
- Returns read data via UART

### Slave 1: Local Memory (2KB)
- Standard memory slave
- No split transaction support

### Slave 2: Local Memory (4KB)
- Standard memory slave
- No split transaction support

### Slave 3: Bus Bridge Slave
- Receives commands from local bus
- Forwards commands via UART to external bus system
- Returns read data from external system

---

## Demo Controls

### Push Buttons
| Button | Function |
|--------|----------|
| **KEY[0]** | Trigger transaction (press to send) |
| **KEY[1]** | Increment data pattern (+1 each press) |

### DIP Switches
| Switch | Function |
|--------|----------|
| **SW[0]** | Reset (HIGH = reset active, LOW = run) |
| **SW[1]** | Master select: 0 = Master 1 (local), 1 = unused |
| **SW[3:2]** | Slave & Mode select (see table below) |

### Slave/Mode Selection (SW[3:2])
| SW[3:2] | Slave | Operation |
|---------|-------|-----------|
| **00** | Slave 1 (2KB Local) | Write |
| **01** | Slave 2 (4KB Local) | Write |
| **10** | Slave 3 (Bus Bridge) | Write (forwards to external) |
| **11** | Slave 1 | Read (read back data) |

---

## LED Display

| LED | Function |
|-----|----------|
| **LED[1:0]** | Slave number (binary: 00=S1, 01=S2, 10=S3) |
| **LED[7:2]** | Last 6 bits of data sent/received |

---

## GPIO Pin Assignments

### Bus Bridge UART Interface
| Signal | DE0-Nano Pin | Direction | Description |
|--------|--------------|-----------|-------------|
| GPIO_0_BRIDGE_M_TX | PIN_A8 | Output | Bridge Master UART TX |
| GPIO_0_BRIDGE_M_RX | PIN_D3 | Input | Bridge Master UART RX |
| GPIO_0_BRIDGE_S_TX | PIN_B8 | Output | Bridge Slave UART TX |
| GPIO_0_BRIDGE_S_RX | PIN_C3 | Input | Bridge Slave UART RX |

### UART Configuration
- **Baud Rate**: 9600
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None

---

## Inter-Bus Communication

### Two-Board Setup

To demonstrate inter-bus communication, connect two DE0-Nano boards:

```
Board A (Bus A)                    Board B (Bus B)
┌─────────────────┐               ┌─────────────────┐
│  Bridge Master  │               │  Bridge Slave   │
│  TX ──────────────────────────► RX               │
│  RX ◄────────────────────────── TX               │
│                 │               │                 │
│  Bridge Slave   │               │  Bridge Master  │
│  TX ──────────────────────────► RX               │
│  RX ◄────────────────────────── TX               │
└─────────────────┘               └─────────────────┘
```

### Wiring

| Board A Pin | Wire | Board B Pin |
|-------------|------|-------------|
| GPIO_0_BRIDGE_M_TX (A8) | → | GPIO_0_BRIDGE_S_RX (C3) |
| GPIO_0_BRIDGE_M_RX (D3) | ← | GPIO_0_BRIDGE_S_TX (B8) |
| GPIO_0_BRIDGE_S_TX (B8) | → | GPIO_0_BRIDGE_M_RX (D3) |
| GPIO_0_BRIDGE_S_RX (C3) | ← | GPIO_0_BRIDGE_M_TX (A8) |
| GND | ↔ | GND |

---

## Demo Walkthrough

### Test 1: Local Bus Operation
1. Set SW[3:2] = 00 (Slave 1, Write)
2. Press KEY[0] to write data to local Slave 1
3. Observe LEDs showing slave number and data

### Test 2: Inter-Bus Write (via Bridge)
1. Set SW[3:2] = 10 (Slave 3 - Bridge Slave)
2. Press KEY[0] to write
3. Data is sent via UART to external bus system

### Test 3: Read Back
1. Set SW[3:2] = 11 (Read from Slave 1)
2. Press KEY[0] to read
3. LEDs show the read data

---

## UART Protocol

### Command Packet Format (21 bits)
```
[20]     [19:12]    [11:0]
 mode     data       addr
  │        │          │
  │        │          └── 12-bit memory address
  │        └───────────── 8-bit write data
  └────────────────────── 1=Write, 0=Read
```

### Response Packet Format (8 bits)
```
[7:0]
 data
  │
  └── 8-bit read data (only for read operations)
```

---

## Files

| File | Description |
|------|-------------|
| `rtl/demo_bridge_top.v` | Top module with bus bridges |
| `rtl/core/bus_bridge_master.v` | Bridge master module |
| `rtl/core/bus_bridge_slave.v` | Bridge slave module |
| `rtl/core/uart.v` | UART transceiver |
| `rtl/core/fifo.v` | Command FIFO buffer |
| `rtl/core/addr_convert.v` | Address converter |
| `constraints/demo_bridge_top.sdc` | Timing constraints |
| `pin_assignments/DE0_Nano_Bridge_Pin_Assignments.tcl` | Pin assignments |
| `tb/demo_bridge_top_tb.sv` | Testbench |

---

## Quartus Project Setup

1. Create new Quartus project targeting **EP4CE22F17C6**
2. Add RTL files:
   - `rtl/demo_bridge_top.v` (top module)
   - `rtl/core/*.v` (all core modules)
3. Set top-level entity: `demo_bridge_top`
4. Import pin assignments: `source pin_assignments/DE0_Nano_Bridge_Pin_Assignments.tcl`
5. Add timing constraints: `constraints/demo_bridge_top.sdc`
6. Compile and program
