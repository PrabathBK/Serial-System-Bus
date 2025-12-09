# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Synthesis**: `./scripts/synthesize_and_verify.sh` (Quartus: map, fit, asm, sta)
- **Full sim**: `./sim/run_sim.sh` (master2_slave3_tb.sv)
- **Single test**: `./sim/run_simple_test.sh` (simple_read_test.sv)
- **Demo test**: `./sim/run_demo_bridge_test.sh` (tb_demo_uart_bridge.sv, 19 tests)
- **Dual system**: `./sim/run_dual_system_test.sh` (tb_dual_system.sv)
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`

## Code Style (Verilog .v)
- **Timescale**: `` `timescale 1ns / 1ps `` at top of each file
- **Naming**: modules/signals `lowercase_underscore`, parameters/states `UPPER_CASE`
- **Reset**: Active-low `rstn`, async: `always @(posedge clk or negedge rstn)`
- **FSM**: Separate comb (`always @(*)`) and seq blocks; states as `localparam`
- **Headers**: `//===` or `//---` block with module name, description, target device

## Testbench Style (SystemVerilog .sv)
- Clock: `parameter CLK_PERIOD=10; forever #(CLK_PERIOD/2) clk=~clk;`
- Output: `$display("PASS: ...")` or `$display("ERROR: ...")` with `$finish`
- Waveforms: `$dumpfile("name.vcd"); $dumpvars(0, module);`

## Key Files
- **Top-level**: `rtl/demo_uart_bridge.v`, **Bus core**: `rtl/core/bus_m2_s3.v`
- **Main TB**: `tb/master2_slave3_tb.sv`, **Demo TB**: `tb/tb_demo_uart_bridge.sv`