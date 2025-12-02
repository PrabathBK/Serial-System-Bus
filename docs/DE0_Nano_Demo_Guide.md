# ADS Bus System Demo - DE0-Nano Guide

## Target Board
**Terasic DE0-Nano** (Intel Cyclone IV EP4CE22F17C6)

---

## Demo Configuration

The demo is configured via `localparam` values in `ads_bus_demo_de0nano.v`:

```verilog
// Which master sends the transaction (0 = Master1, 1 = Master2)
localparam DEMO_MASTER_SELECT = 1'b0;   // Use Master 1

// Target slave (2'b00=Slave1, 2'b01=Slave2, 2'b10=Slave3)
localparam [1:0] DEMO_SLAVE_SELECT = 2'b00;  // Target Slave 1

// Data pattern to send (8 bits)
localparam [7:0] DEMO_DATA_PATTERN = 8'hA5;  // 10100101

// Memory address within the slave
localparam [11:0] DEMO_MEM_ADDR = 12'h010;

// Transaction mode (0 = Read, 1 = Write)
localparam DEMO_MODE = 1'b1;            // Write operation
```

---

## Controls

| Control | Function |
|---------|----------|
| **SW[0]** | Reset (HIGH = Reset active, LOW = Normal operation) |
| **SW[1-3]** | Reserved for future use |
| **KEY[0]** | Press to trigger a transaction (active low) |
| **KEY[1]** | Reserved |

---

## LED Display

| LED | Function |
|-----|----------|
| **LED[1:0]** | Slave number (binary: 00=Slave1, 01=Slave2, 10=Slave3) |
| **LED[7:2]** | Last 6 bits of data sent/received |

### Example LED Patterns

| Data | Slave | LED[7:0] Pattern |
|------|-------|------------------|
| 0xA5 (10100101) | Slave 1 (00) | `100101_00` = LED 7,5,4,2 ON |
| 0x5A (01011010) | Slave 2 (01) | `011010_01` = LED 6,5,3,1,0 ON |
| 0xFF (11111111) | Slave 3 (10) | `111111_10` = LED 7,6,5,4,3,2,1 ON |

---

## How to Demo

1. **Power on** the DE0-Nano
2. **Set SW[0] = HIGH** momentarily to reset, then **LOW** for normal operation
3. **Press KEY[0]** to trigger a transaction
4. **Observe LEDs**:
   - LED[1:0] shows which slave was accessed
   - LED[7:2] shows the data pattern

---

## Memory Map

| Slave | Device Address | Memory Size | Address Range |
|-------|----------------|-------------|---------------|
| Slave 1 | 2'b00 | 2KB | 0x000-0x7FF |
| Slave 2 | 2'b01 | 4KB | 0x000-0xFFF |
| Slave 3 | 2'b10 | 4KB (SPLIT) | 0x000-0xFFF |

---

## Pin Assignments Summary

| Signal | DE0-Nano Pin | Description |
|--------|--------------|-------------|
| CLOCK_50 | PIN_R8 | 50 MHz oscillator |
| KEY[0] | PIN_J15 | Transaction trigger |
| KEY[1] | PIN_E1 | Reserved |
| SW[0] | PIN_M1 | Reset switch |
| SW[1] | PIN_T8 | Reserved |
| SW[2] | PIN_B9 | Reserved |
| SW[3] | PIN_M15 | Reserved |
| LED[0] | PIN_A15 | Slave select LSB |
| LED[1] | PIN_A13 | Slave select MSB |
| LED[2] | PIN_B13 | Data bit 0 |
| LED[3] | PIN_A11 | Data bit 1 |
| LED[4] | PIN_D1 | Data bit 2 |
| LED[5] | PIN_F3 | Data bit 3 |
| LED[6] | PIN_B1 | Data bit 4 |
| LED[7] | PIN_L3 | Data bit 5 |

---

## Quartus Project Setup

1. Create new Quartus project targeting **EP4CE22F17C6**
2. Add RTL files:
   - `rtl/ads_bus_demo_de0nano.v` (top module)
   - `rtl/core/*.v` (all core modules)
3. Set top-level entity: `ads_bus_demo_de0nano`
4. Import pin assignments: `source pin_assignments/DE0_Nano_Pin_Assignments.tcl`
5. Compile and program

---

## Changing Demo Parameters

To test different scenarios, modify these in `ads_bus_demo_de0nano.v`:

### Test Master 2 → Slave 3 with data 0x55:
```verilog
localparam DEMO_MASTER_SELECT = 1'b1;        // Master 2
localparam [1:0] DEMO_SLAVE_SELECT = 2'b10;  // Slave 3
localparam [7:0] DEMO_DATA_PATTERN = 8'h55;  // 01010101
```

### Test Read operation from Slave 2:
```verilog
localparam DEMO_MODE = 1'b0;                 // Read mode
localparam [1:0] DEMO_SLAVE_SELECT = 2'b01;  // Slave 2
```
