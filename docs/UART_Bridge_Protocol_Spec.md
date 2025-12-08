# UART Bridge Protocol Specification

## Overview

This document defines the UART protocol requirements for inter-FPGA communication with the ADS Serial Bus System. Any external system implementing this protocol can communicate with the bus bridge.

---

## Physical Layer

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Baud Rate** | 9600 bps | Must match exactly |
| **Data Bits** | 8 | Standard UART |
| **Parity** | None | No parity bit |
| **Stop Bits** | 1 | Single stop bit |
| **Bit Order** | LSB first | Standard UART convention |
| **Idle State** | HIGH (1) | TX line idles high |

### Timing Calculations

```
Bit Period = 1 / 9600 = 104.17 us

For your clock frequency:
  CLOCKS_PER_PULSE = CLOCK_FREQ / 9600

Examples:
  50 MHz:  CLOCKS_PER_PULSE = 5208
  100 MHz: CLOCKS_PER_PULSE = 10416
  25 MHz:  CLOCKS_PER_PULSE = 2604
```

---

## Frame Formats

### Command Frame (Bridge Slave TX → Bridge Master RX)

Used to send write/read commands to the remote system.

```
Total: 21 bits + UART framing = 23 bits per byte (start + 8 data + stop) x 3 bytes

Bit Layout:
┌──────┬───────────┬─────────────┐
│ Mode │   Data    │   Address   │
│ [20] │  [19:12]  │   [11:0]    │
│ 1bit │   8bits   │   12bits    │
└──────┴───────────┴─────────────┘

Transmitted as 21 serial bits (LSB first):
  addr[0], addr[1], ..., addr[11], data[0], data[1], ..., data[7], mode
```

| Field | Bits | Description |
|-------|------|-------------|
| **Mode** | [20] | `1` = Write, `0` = Read |
| **Data** | [19:12] | 8-bit write data (ignored for read) |
| **Address** | [11:0] | 12-bit address field |

### Address Field Encoding

```
Address[11:0] breakdown:
┌─────────┬────────────┐
│ Slave   │  Memory    │
│ Select  │  Address   │
│  [11]   │  [10:0]    │
└─────────┴────────────┘

Slave Select (addr[11]):
  0 = Slave 1 (2KB memory, addr 0x000-0x7FF)
  1 = Slave 2 (4KB memory, addr 0x000-0x7FF valid)
```

### Response Frame (Bridge Master TX → Bridge Slave RX)

Used to return read data to the requesting system.

```
Total: 8 bits + UART framing = 10 bits (start + 8 data + stop)

Bit Layout:
┌───────────────────┐
│      Data         │
│      [7:0]        │
│      8bits        │
└───────────────────┘

Transmitted as 8 serial bits (LSB first):
  data[0], data[1], ..., data[7]
```

| Field | Bits | Description |
|-------|------|-------------|
| **Data** | [7:0] | 8-bit read data from slave memory |

---

## Transaction Sequences

### Write Transaction

```
System A                              System B
(Sender)                              (Receiver)
   │                                      │
   │  Command Frame (21 bits)             │
   │  {mode=1, data, addr}                │
   ├─────────────────────────────────────►│
   │                                      │
   │                                      ├── Bridge Master receives
   │                                      ├── Decodes: mode=1 (write)
   │                                      ├── Selects slave via addr[11]
   │                                      └── Writes data to addr[10:0]
   │                                      │
   │  (No response for writes)            │
   │                                      │
```

### Read Transaction

```
System A                              System B
(Requester)                           (Responder)
   │                                      │
   │  Command Frame (21 bits)             │
   │  {mode=0, data=0x00, addr}           │
   ├─────────────────────────────────────►│
   │                                      │
   │                                      ├── Bridge Master receives
   │                                      ├── Decodes: mode=0 (read)
   │                                      ├── Selects slave via addr[11]
   │                                      ├── Reads from addr[10:0]
   │                                      │
   │  Response Frame (8 bits)             │
   │  {data}                              │
   │◄─────────────────────────────────────┤
   │                                      │
   ├── Bridge Slave receives              │
   └── Returns data to local master       │
```

---

## Timing Requirements

### Command Frame Timing

```
21 bits at 9600 baud:
  Bit time = 104.17 us
  Frame time = 21 × 104.17 us = 2.19 ms
  With UART framing (3 bytes): ~3.1 ms
```

### Response Frame Timing

```
8 bits at 9600 baud:
  Frame time = 8 × 104.17 us = 0.83 ms
  With UART framing (1 byte): ~1.04 ms
```

### Total Transaction Time

| Transaction Type | Minimum Time |
|------------------|--------------|
| Write only | ~3.1 ms |
| Read (request + response) | ~4.2 ms |

---

## Wiring Diagram

### Bidirectional Communication (Two Systems)

```
System A                                    System B
┌────────────────────┐                      ┌────────────────────┐
│                    │                      │                    │
│  Bridge Slave      │                      │  Bridge Master     │
│  ┌──────────┐      │                      │      ┌──────────┐  │
│  │ UART TX  │──────┼──────────────────────┼─────►│ UART RX  │  │
│  │ (S_TX)   │      │   Command Frame      │      │ (M_RX)   │  │
│  └──────────┘      │                      │      └──────────┘  │
│  ┌──────────┐      │                      │      ┌──────────┐  │
│  │ UART RX  │◄─────┼──────────────────────┼──────│ UART TX  │  │
│  │ (S_RX)   │      │   Response Frame     │      │ (M_TX)   │  │
│  └──────────┘      │                      │      └──────────┘  │
│                    │                      │                    │
│  Bridge Master     │                      │  Bridge Slave      │
│  ┌──────────┐      │                      │      ┌──────────┐  │
│  │ UART RX  │◄─────┼──────────────────────┼──────│ UART TX  │  │
│  │ (M_RX)   │      │   Command Frame      │      │ (S_TX)   │  │
│  └──────────┘      │                      │      └──────────┘  │
│  ┌──────────┐      │                      │      ┌──────────┐  │
│  │ UART TX  │──────┼──────────────────────┼─────►│ UART RX  │  │
│  │ (M_TX)   │      │   Response Frame     │      │ (S_RX)   │  │
│  └──────────┘      │                      │      └──────────┘  │
│                    │                      │                    │
│       GND ─────────┼──────────────────────┼───────── GND       │
└────────────────────┘                      └────────────────────┘
```

### Pin Connections Summary

| System A Pin | Wire | System B Pin | Purpose |
|--------------|------|--------------|---------|
| S_TX | → | M_RX | A sends commands to B |
| S_RX | ← | M_TX | A receives responses from B |
| M_RX | ← | S_TX | A receives commands from B |
| M_TX | → | S_RX | A sends responses to B |
| GND | — | GND | Common ground (required!) |

---

## Implementation Requirements

### For a Compatible Bridge Master (Receiver)

Your system must implement:

```verilog
// 1. UART Receiver
//    - 9600 baud, 8N1
//    - Receive 21-bit frames (3 bytes)

// 2. Frame Parser
wire        mode = rx_data[20];      // 1=write, 0=read
wire [7:0]  data = rx_data[19:12];   // write data
wire [11:0] addr = rx_data[11:0];    // address

// 3. Address Decoder
wire slave_sel = addr[11];           // 0=S1, 1=S2
wire [10:0] mem_addr = addr[10:0];   // memory address

// 4. Bus Transaction
//    - If mode=1: Write data to selected slave at mem_addr
//    - If mode=0: Read from selected slave, send response

// 5. UART Transmitter (for read responses)
//    - 9600 baud, 8N1
//    - Transmit 8-bit read data
```

### For a Compatible Bridge Slave (Sender)

Your system must implement:

```verilog
// 1. Command Builder
wire [20:0] tx_frame = {mode, data, addr};

// 2. UART Transmitter
//    - 9600 baud, 8N1
//    - Transmit 21-bit frames

// 3. UART Receiver (for read responses)
//    - 9600 baud, 8N1
//    - Receive 8-bit response frames

// 4. Response Handler
//    - Return read data to local bus master
```

---

## Example Transactions

### Example 1: Write 0xAB to Slave 1, Address 0x100

```
Command Frame (21 bits):
  mode = 1 (write)
  data = 0xAB
  addr = 0x100 (addr[11]=0 selects S1, addr[10:0]=0x100)

Binary: 1_10101011_000100000000
        │ │      │ │          │
        │ │      │ └──────────┴── addr[11:0] = 0x100
        │ └──────┴─────────────── data[7:0] = 0xAB
        └──────────────────────── mode = 1 (write)

Hex representation: 0x1AB100
```

### Example 2: Read from Slave 2, Address 0x050

```
Command Frame (21 bits):
  mode = 0 (read)
  data = 0x00 (don't care)
  addr = 0x850 (addr[11]=1 selects S2, addr[10:0]=0x050)

Binary: 0_00000000_100001010000
        │ │      │ │          │
        │ │      │ └──────────┴── addr[11:0] = 0x850
        │ └──────┴─────────────── data[7:0] = 0x00
        └──────────────────────── mode = 0 (read)

Response Frame (8 bits):
  data = (value read from memory)
```

---

## Error Handling

### Current Implementation Limitations

| Issue | Current Behavior | Recommendation |
|-------|------------------|----------------|
| Frame errors | Ignored | Add frame validation |
| Timeout | 500K cycles (~10ms) | Configurable timeout |
| Buffer overflow | FIFO depth = 8 | Don't send > 8 commands without waiting |
| No ACK/NAK | Writes are fire-and-forget | Add acknowledgment for critical writes |

### Recommended Timeouts

| Operation | Timeout |
|-----------|---------|
| Write command | 5 ms (frame transmission) |
| Read request | 5 ms (request transmission) |
| Read response | 10 ms (includes slave access time) |
| Total read transaction | 20 ms |

---

## Quick Reference

### Frame Summary

| Frame Type | Size | Format | Direction |
|------------|------|--------|-----------|
| Command | 21 bits | `{mode[1], data[8], addr[12]}` | Slave TX → Master RX |
| Response | 8 bits | `{data[8]}` | Master TX → Slave RX |

### Address Mapping

| Address Range | Slave | Memory Size |
|---------------|-------|-------------|
| 0x000 - 0x7FF | Slave 1 | 2 KB |
| 0x800 - 0xFFF | Slave 2 | 4 KB |

### Mode Encoding

| Mode Bit | Operation |
|----------|-----------|
| 0 | Read |
| 1 | Write |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2025 | Initial specification |
