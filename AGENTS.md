# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Synthesis**: `./scripts/synthesize_and_verify.sh` (Quartus: map, fit, asm, sta)
- **Full sim**: `./sim/run_sim.sh` (Vivado xsim, master2_slave3_tb.sv)
- **Single test**: `./sim/run_simple_test.sh` (simple_read_test.sv)
- **Dual system**: `./sim/run_dual_system_test.sh` (tb_dual_system.sv)
- **Demo bridge**: `./sim/run_demo_bridge_test.sh` (tb_demo_uart_bridge.sv)
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

Always update `todo.md` and `AGENTS.md` when making significant changes.