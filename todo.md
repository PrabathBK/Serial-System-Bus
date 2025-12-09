# ADS Serial Bus System - Project TODO

## Target Platform
- **Board**: Terasic DE0-Nano
- **Device**: Intel Cyclone IV EP4CE22F17C6
- **Top-Level Module**: `demo_uart_bridge.v`

## Completed
- [x] 2-master, 3-slave bus system implementation
- [x] Priority-based arbiter with split transaction support
- [x] Async reset pattern in all RTL modules
- [x] UART bus bridge for inter-FPGA communication
- [x] Quartus synthesis scripts
- [x] Documentation cleanup (removed outdated DE10-Nano/Cyclone V references)
- [x] All RTL comments updated to DE0-Nano/Cyclone IV EP4CE22F17C6
- [x] Memory references updated (M10K → M9K)
- [x] Fixed both_keys_pressed detection logic for KEY[0]+KEY[1] reset
- [x] Fixed demo FSM read data capture timing (added DEMO_WAIT_START state)
- [x] Added comprehensive testbench coverage (19 tests)

## Testbenches Status (Last Run: Dec 9, 2025)
| Testbench | Assignment Task | Status | Result |
|-----------|-----------------|--------|--------|
| `tb_arbiter.sv` | Task 2 - Arbiter Verification | Complete | ALL PASS |
| `tb_addr_decoder.sv` | Task 3 - Address Decoder Verification | Complete | ALL PASS |
| `master2_slave3_tb.sv` | Task 4 - Top-level Verification | Complete | ALL PASS (20 iterations) |
| `simple_read_test.sv` | Debug/Quick Test | Complete | ALL PASS (7/7 tests) |
| `tb_dual_system.sv` | Multi-FPGA Bridge Testing | Complete | ALL PASS (7/7 tests) |
| `tb_demo_uart_bridge.sv` | DE0-Nano Top-Level Testing | Complete | ALL PASS (19/19 tests) |

## Verification Status
- [x] Arbiter verification (reset, single/dual master, split)
- [x] Address decoder verification (3 slaves, address mapping, reset, slave select)
- [x] Top-level verification (reset, 1/2 master requests, split)
- [x] Bus bridge UART communication
- [x] Read-back verification in demo testbench
- [x] Address auto-increment after writes
- [x] Both-keys reset functionality

## Memory Configuration
| Slave | Size | Address Range | Split Support |
|-------|------|---------------|---------------|
| Slave 1 | 2KB | 0x0000-0x07FF | No |
| Slave 2 | 4KB | 0x1000-0x1FFF | No |
| Slave 3 | 4KB | 0x2000-0x2FFF | Yes (Bridge) |

## Dual-System Bridge Test Cases (tb_dual_system.sv)
| Test | Description | Status |
|------|-------------|--------|
| Test 1 | Internal Write: System A M1 -> System A S1 | PASS |
| Test 2 | Internal Write: System A M1 -> System A S2 | PASS |
| Test 3 | External Write: System A M1 -> System B S1 (via bridge) | PASS |
| Test 4 | External Write: System A M1 -> System B S2 (via bridge) | PASS |
| Test 5 | Internal Write: System A M1 -> System A S3 (local memory) | PASS |
| Test 6 | Bridge Write: System A M2 -> System A S3 (via UART from B) | PASS |
| Test 7 | External Write: System A M1 -> System B S3 (via bridge) | PASS |

## Demo UART Bridge Test Cases (tb_demo_uart_bridge.sv)
| Test | Description | Status |
|------|-------------|--------|
| Test 1 | Internal Write: A:M1 -> A:S1 | PASS |
| Test 2 | Internal Write: A:M1 -> A:S2 | PASS |
| Test 3 | External Write: A:M1 -> B:S1 (via UART bridge) | PASS |
| Test 4 | External Write: A:M1 -> B:S2 (via UART bridge) | PASS |
| Test 5 | Internal Read: A:M1 -> A:S1 (read back) | PASS |
| Test 6 | External Write: B:M1 -> A:S1 (reverse direction) | PASS |
| Test 7 | External Read: A:M1 -> B:S1 (read via bridge) | PASS |
| Test 8 | Internal Read: A:M1 -> A:S2 (read back) | PASS |
| Test 9 | External Write: B:M1 -> A:S2 (reverse direction) | PASS |
| Test 10 | External Read: B:M1 -> A:S2 (reverse direction) | PASS |
| Test 11 | External Read: A:M1 -> B:S2 (read via bridge) | PASS |
| Test 12 | Bidirectional: A->B:S1 and B->A:S1 (concurrent) | PASS |
| Test 13 | Write-Read Verify: A writes to B:S1, reads back | PASS |
| Test 14 | Write-Read Verify: B writes to A:S2, reads back | PASS |
| Test 15 | Address increment in read mode (KEY[1] only) | PASS |
| Test 16 | Address auto-increment after writes | PASS |
| Test 17 | Reset both counters (KEY[0]+KEY[1] together) | PASS |
| Test 18 | Write-Read with address selection | PASS |
| Test 19 | Mode switching (write -> read transitions) | PASS |

## Demo Control Scheme (demo_uart_bridge.v)
- **KEY[0]**: Initiate transfer (read or write based on SW[3])
- **KEY[1]**: Increment value (data in write mode, address in read mode)
- **KEY[0]+KEY[1]**: Press both together to reset both counters to 0
- **SW[0]**: Reset (active HIGH)
- **SW[1]**: Slave select (0=S1, 1=S2)
- **SW[2]**: Mode (0=Internal, 1=External via Bridge)
- **SW[3]**: Read/Write (0=Read, 1=Write)
- **LED[7:0]**: Shows data_pattern in write mode, read_data in read mode

## Future Improvements
- [ ] Implement error detection/recovery
- [ ] Add performance counters
- [x] Multi-FPGA bridge testing
- [x] DE0-Nano top-level testbench (tb_demo_uart_bridge.sv)
- [x] Add read-back verification in testbench
- [ ] Add DE0-Nano pin assignments documentation
