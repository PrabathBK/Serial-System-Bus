# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Synthesis**: `./scripts/synthesize_and_verify.sh` (Quartus: map, fit, asm, sta; ~5-7 min)
  - Single phase: `./scripts/synthesize_and_verify.sh --phase <map|fit|asm|sta>`
- **Full sim**: `./sim/run_sim.sh` (master2_slave3_tb.sv - comprehensive bus test)
- **Bus core test**: `./sim/run_bus_m2_s3_simple_test.sh` (tb_bus_m2_s3_simple.sv - 5 basic tests)
- **Single test**: `./sim/run_simple_test.sh` (simple_read_test.sv - quick debug)
- **Demo test**: `./sim/run_demo_bridge_test.sh` (tb_demo_uart_bridge.sv - 19 UART bridge tests)
- **Dual system**: `./sim/run_dual_system_test.sh` (tb_dual_system.sv - inter-FPGA communication)
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`
- **Simulator**: Xilinx Vivado xsim (xvlog → xelab → xsim), generates .vcd for GTKWave
- **Target**: Intel Cyclone IV EP4CE22F17C6 / Cyclone V 5CSEBA6U23I7 (DE0-Nano/DE10-Nano)

## Code Style (Verilog .v)
- **Timescale**: `` `timescale 1ns / 1ps `` at top of every file (required for xsim)
- **Naming**: modules/signals/wires `lowercase_underscore`, parameters/states `UPPER_CASE`
- **Reset**: Active-low `rstn`, async reset: `always @(posedge clk or negedge rstn)`
- **FSM**: Separate combinational (`always @(*)`) and sequential blocks; states as `localparam`
- **Headers**: `//===` or `//---` block with module name, description, parameters, target device
- **Parameters**: Use `#(parameter ADDR_WIDTH=16, ...)` for configurable modules
- **Comments**: Inline explanations for non-obvious logic; block comments for major sections
- **Init**: Sequential blocks: `if (!rstn) begin /* reset */ end else begin /* logic */ end`

## Testbench Style (SystemVerilog .sv)
- **Clock**: `parameter CLK_PERIOD=10; initial clk=0; always #(CLK_PERIOD/2) clk=~clk;`
- **Reset**: Assert `rstn=0` for 2-3 cycles, then release to 1
- **Output**: `$display("PASS: test_name - details")` or `$display("ERROR: test_name - reason")`
- **Finish**: Use `$finish;` after all tests complete
- **Waveforms**: `$dumpfile("testbench_name.vcd"); $dumpvars(0, testbench_module);`
- **Timing**: Use `#(CLK_PERIOD*N)` delays; wait for `dready` signals before new transactions
- **Test structure**: Number tests, track pass/fail counts, display summary at end

## Key Files & Architecture
- **Top-level**: `rtl/demo_uart_bridge.v` (DE0-Nano w/ KEY/SW/LED + UART bridge)
- **Bus core**: `rtl/core/bus_m2_s3.v` (2 masters, 3 slaves, priority arbiter, split transactions)
- **Masters**: `master_port.v` (8-state FSM), **Slaves**: `slave.v` + `slave_port.v`
- **Arbiter**: `arbiter.v` (3-state FSM, M1 priority > M2, split transaction support)
- **Decoder**: `addr_decoder.v` (4-bit device addr → slave select, 12-bit mem addr)
- **UART Bridge**: `bus_bridge_master.v`, `bus_bridge_slave.v` (inter-FPGA via serial)
- **Main TB**: `tb/master2_slave3_tb.sv` (unit/integration tests)
- **Demo TB**: `tb/tb_demo_uart_bridge.sv` (dual-system UART bridge verification)