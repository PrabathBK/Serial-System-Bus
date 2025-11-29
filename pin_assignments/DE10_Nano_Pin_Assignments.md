# ADS Bus System - Pin Assignment Documentation
# Target: Terasic DE10-Nano Development Board
# Device: Intel Cyclone V 5CSEBA6U23I7
# Date: October 14, 2025

## Pin Assignment Summary

### Clock and Reset
| Signal Name    | Pin Location | I/O Standard | Direction | Description                    |
|----------------|--------------|--------------|-----------|--------------------------------|
| FPGA_CLK1_50   | PIN_V11      | 3.3-V LVTTL  | Input     | 50 MHz system clock            |
| KEY0           | PIN_AH17     | 3.3-V LVTTL  | Input     | Push button reset (active low) |

### Status LEDs
| Signal Name | Pin Location | I/O Standard | Direction | Description                |
|-------------|--------------|--------------|-----------|----------------------------|
| LED[0]      | PIN_W15      | 3.3-V LVTTL  | Output    | Reset status indicator     |
| LED[1]      | PIN_AA24     | 3.3-V LVTTL  | Output    | Master 1 bus grant         |
| LED[2]      | PIN_V16      | 3.3-V LVTTL  | Output    | Master 2 bus grant         |
| LED[3]      | PIN_V15      | 3.3-V LVTTL  | Output    | Master 1 acknowledge       |
| LED[4]      | PIN_AF26     | 3.3-V LVTTL  | Output    | Master 2 acknowledge       |
| LED[5]      | PIN_AE26     | 3.3-V LVTTL  | Output    | Master 1 split transaction |
| LED[6]      | PIN_Y16      | 3.3-V LVTTL  | Output    | Master 2 split transaction |
| LED[7]      | PIN_AA23     | 3.3-V LVTTL  | Output    | Reserved                   |

### Master 1 Interface (GPIO - Arduino Header Pins 0-8)
| Signal Name      | Pin Location | I/O Standard | Direction | Description                    |
|------------------|--------------|--------------|-----------|--------------------------------|
| GPIO_M1_RDATA    | PIN_AG9      | 3.3-V LVTTL  | Output    | Master 1 read data (serial)    |
| GPIO_M1_WDATA    | PIN_AF10     | 3.3-V LVTTL  | Input     | Master 1 write data (serial)   |
| GPIO_M1_MODE     | PIN_AG10     | 3.3-V LVTTL  | Input     | Master 1 mode (0=R, 1=W)       |
| GPIO_M1_MVALID   | PIN_AF8      | 3.3-V LVTTL  | Input     | Master 1 valid signal          |
| GPIO_M1_SVALID   | PIN_AF9      | 3.3-V LVTTL  | Output    | Slave valid to master 1        |
| GPIO_M1_BREQ     | PIN_AD11     | 3.3-V LVTTL  | Input     | Master 1 bus request           |
| GPIO_M1_BGRANT   | PIN_AD12     | 3.3-V LVTTL  | Output    | Master 1 bus grant             |
| GPIO_M1_ACK      | PIN_AE11     | 3.3-V LVTTL  | Output    | Master 1 acknowledge           |
| GPIO_M1_SPLIT    | PIN_AE12     | 3.3-V LVTTL  | Output    | Master 1 split signal          |

### Master 2 Interface (GPIO - Arduino Header Pins 9-17)
| Signal Name      | Pin Location | I/O Standard | Direction | Description                    |
|------------------|--------------|--------------|-----------|--------------------------------|
| GPIO_M2_RDATA    | PIN_AF17     | 3.3-V LVTTL  | Output    | Master 2 read data (serial)    |
| GPIO_M2_WDATA    | PIN_AF15     | 3.3-V LVTTL  | Input     | Master 2 write data (serial)   |
| GPIO_M2_MODE     | PIN_AG16     | 3.3-V LVTTL  | Input     | Master 2 mode (0=R, 1=W)       |
| GPIO_M2_MVALID   | PIN_AG15     | 3.3-V LVTTL  | Input     | Master 2 valid signal          |
| GPIO_M2_SVALID   | PIN_AH14     | 3.3-V LVTTL  | Output    | Slave valid to master 2        |
| GPIO_M2_BREQ     | PIN_AG14     | 3.3-V LVTTL  | Input     | Master 2 bus request           |
| GPIO_M2_BGRANT   | PIN_AH8      | 3.3-V LVTTL  | Output    | Master 2 bus grant             |
| GPIO_M2_ACK      | PIN_AF11     | 3.3-V LVTTL  | Output    | Master 2 acknowledge           |
| GPIO_M2_SPLIT    | PIN_AG11     | 3.3-V LVTTL  | Output    | Master 2 split signal          |

## Memory Map

### Slave Devices
| Slave ID | Device Address | Memory Size | Address Range | Split Support |
|----------|----------------|-------------|---------------|---------------|
| Slave 1  | 2'b00 (0)      | 2KB         | 0x000-0x7FF   | No            |
| Slave 2  | 2'b01 (1)      | 4KB         | 0x000-0xFFF   | No            |
| Slave 3  | 2'b10 (2)      | 4KB         | 0x000-0xFFF   | Yes           |

### Addressing Scheme
- Total Address Width: 16 bits
- Device Address: 4 bits (transmitted MSB-first)
- Memory Address: 11-12 bits depending on slave (transmitted LSB-first)
- Data Width: 8 bits (transmitted LSB-first)

## Usage Notes

1. **Clock Source**: The 50 MHz clock is provided by the on-board oscillator at PIN_V11
2. **Reset**: KEY0 is an active-low push button. When pressed, system is held in reset
3. **LEDs**: Can be used for real-time status monitoring during operation
4. **GPIO Connections**: Master interfaces are mapped to Arduino header for easy external connection
5. **Voltage Levels**: All I/Os use 3.3V LVTTL standard
6. **Slave Devices**: Internal to FPGA, implemented using M10K block RAM

## Connection Diagram

```
DE10-Nano Board
┌─────────────────────────────────────────┐
│                                         │
│  FPGA_CLK1_50 (PIN_V11) ────→ [Clock]  │
│  KEY0 (PIN_AH17) ────→ [Reset]          │
│                                         │
│  Arduino Header GPIO (Master 1)         │
│  ├─ PIN_AG9  : M1_RDATA   (out)         │
│  ├─ PIN_AF10 : M1_WDATA   (in)          │
│  ├─ PIN_AG10 : M1_MODE    (in)          │
│  ├─ PIN_AF8  : M1_MVALID  (in)          │
│  ├─ PIN_AF9  : M1_SVALID  (out)         │
│  ├─ PIN_AD11 : M1_BREQ    (in)          │
│  ├─ PIN_AD12 : M1_BGRANT  (out)         │
│  ├─ PIN_AE11 : M1_ACK     (out)         │
│  └─ PIN_AE12 : M1_SPLIT   (out)         │
│                                         │
│  Arduino Header GPIO (Master 2)         │
│  ├─ PIN_AF17 : M2_RDATA   (out)         │
│  ├─ PIN_AF15 : M2_WDATA   (in)          │
│  ├─ PIN_AG16 : M2_MODE    (in)          │
│  ├─ PIN_AG15 : M2_MVALID  (in)          │
│  ├─ PIN_AH14 : M2_SVALID  (out)         │
│  ├─ PIN_AG14 : M2_BREQ    (in)          │
│  ├─ PIN_AH8  : M2_BGRANT  (out)         │
│  ├─ PIN_AF11 : M2_ACK     (out)         │
│  └─ PIN_AG11 : M2_SPLIT   (out)         │
│                                         │
│  Status LEDs (8 LEDs)                   │
│  ├─ LED[0] : Reset Status               │
│  ├─ LED[1] : M1 Bus Grant               │
│  ├─ LED[2] : M2 Bus Grant               │
│  ├─ LED[3] : M1 Acknowledge             │
│  ├─ LED[4] : M2 Acknowledge             │
│  ├─ LED[5] : M1 Split                   │
│  ├─ LED[6] : M2 Split                   │
│  └─ LED[7] : Reserved                   │
│                                         │
└─────────────────────────────────────────┘
```

## Timing Characteristics

- **Clock Frequency**: 50 MHz (20 ns period)
- **Fmax Goal**: > 50 MHz (design should achieve 100+ MHz)
- **Input Setup Time**: 3 ns max
- **Output Delay**: 2 ns max
- **Clock Uncertainty**: Derived automatically by Quartus

## Resource Utilization Estimates

Based on similar Cyclone V designs:
- **Logic Elements (ALMs)**: ~500-800 (< 1% of 110K available)
- **Registers**: ~300-500
- **Memory (M10K blocks)**: 10 blocks for 10KB total (Slave1:2KB, Slave2:4KB, Slave3:4KB)
- **DSP Blocks**: 0
- **PLLs**: 0
- **I/O Pins**: 27 (Clock, Reset, 8 LEDs, 18 GPIO)

## Design Hierarchy

```
ads_bus_top
├── bus_m2_s3
│   ├── arbiter
│   ├── addr_decoder
│   │   └── dec3
│   ├── mux2 (master selection)
│   ├── mux3 (slave selection)
│   └── routing logic
├── slave1_inst (2KB, no split)
│   ├── slave_port
│   └── slave_memory_bram
├── slave2_inst (4KB, no split)
│   ├── slave_port
│   └── slave_memory_bram
└── slave3_inst (4KB, split enabled)
    ├── slave_port
    └── slave_memory_bram
```
