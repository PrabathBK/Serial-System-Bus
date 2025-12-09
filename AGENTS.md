# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Synthesis**: `./scripts/synthesize_and_verify.sh` (Quartus: map, fit, asm, sta)
- **Full sim**: `./sim/run_sim.sh` (Vivado xsim, master2_slave3_tb.sv)
- **Single test**: `./sim/run_simple_test.sh` (simple_read_test.sv)
- **Dual system**: `./sim/run_dual_system_test.sh` (tb_dual_system.sv)
- **Demo bridge**: `./sim/run_demo_bridge_test.sh` (tb_demo_uart_bridge.sv) - **19 tests**
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`

## Code Style (Verilog .v)
- **Timescale**: `` `timescale 1ns / 1ps `` at top of each file
- **Naming**: modules/signals `lowercase_underscore`, parameters/states `UPPER_CASE`
- **Reset**: Active-low `rstn`, async: `always @(posedge clk or negedge rstn)`
- **FSM**: Separate comb (`always @(*)`) and seq blocks; states as `localparam IDLE=3'b000`
- **Headers**: `//---` block with module name, description, target device

## Testbench Style (SystemVerilog .sv)
- Clock: `parameter CLK_PERIOD=10; forever #(CLK_PERIOD/2) clk=~clk;`
- Output: `$display("PASS: ...")` or `$display("ERROR: ...")` with `$finish`
- Waveforms: `$dumpfile("name.vcd"); $dumpvars(0, module);`

## Key Files
- **Top-level**: `rtl/demo_uart_bridge.v`, **Core**: `rtl/core/bus_m2_s3.v`
- **Main testbench**: `tb/master2_slave3_tb.sv` (Task 4 comprehensive test)
- **Demo testbench**: `tb/tb_demo_uart_bridge.sv` (DE0-Nano top-level, 19 tests)

## Demo Control Scheme (demo_uart_bridge.v)
- **KEY[0]**: Initiate transfer (read or write based on SW[3])
- **KEY[1]**: Increment value (data in write mode, address in read mode)
- **KEY[0]+KEY[1]**: Press both together to reset both counters to 0
- **SW[0]**: Reset (active HIGH), **SW[1]**: Slave select (0=S1, 1=S2)
- **SW[2]**: Mode (0=Internal, 1=External), **SW[3]**: R/W (0=Read, 1=Write)
- **LED[7:0]**: Shows data_pattern (write mode) or read_data (read mode)

## Recent Fixes (Dec 2025)
- Fixed `both_keys_pressed` detection using `both_keys_held` edge detection
- Added `DEMO_WAIT_START` state to fix read data capture timing
- Demo FSM states: IDLE -> START -> WAIT_START -> WAIT -> COMPLETE -> DISPLAY

Always update `todo.md` and `AGENTS.md` when making significant changes.