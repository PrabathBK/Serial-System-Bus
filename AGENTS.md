# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Full synthesis**: `./scripts/synthesize_and_verify.sh` (runs: map→fit→asm→sta)
  - Partial: `./scripts/synthesize_and_verify.sh --phase map` (only synthesis)
  - Partial: `./scripts/synthesize_and_verify.sh --phase sta` (only timing)
- **Simulations** (Xilinx xsim, from project root):
  - Full: `./sim/run_sim.sh` (master2_slave3_tb.sv, all bus transactions)
  - Single: `./sim/run_simple_test.sh` (simple_read_test.sv, quick debug)
  - Demo: `./sim/run_demo_bridge_test.sh` (tb_demo_uart_bridge.sv, 19 UART bridge tests)
  - Dual: `./sim/run_dual_system_test.sh` (tb_dual_system.sv, inter-FPGA)
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`
- **View waves**: `gtkwave sim/<testbench_name>.vcd` (after simulation)

## Code Style (Verilog .v)
- **Headers**: Start with `//===` block: module name, description, target device, date, author
- **Timescale**: `` `timescale 1ns / 1ps `` immediately after header
- **Naming**: 
  - Modules/signals/wires/regs: `lowercase_with_underscores`
  - Parameters/localparams/states: `UPPER_CASE_WITH_UNDERSCORES`
  - Active-low signals: suffix with `n` (e.g., `rstn`, `cs_n`)
- **Reset**: Active-low `rstn`, async reset: `always @(posedge clk or negedge rstn)`
- **FSM style**: 
  - States as `localparam` (e.g., `localparam IDLE = 2'b00;`)
  - Separate combinational (`always @(*)`) and sequential (`always @(posedge clk)`) blocks
  - Avoid latches: always provide `default` in case statements
- **Parameters**: Define at module level with clear comments, use for memory widths/sizes
- **Comments**: 
  - Use `//` for single-line, `/* */` for multi-line blocks
  - Document complex FSM transitions, split transaction logic, UART protocol details
  - Add `//NOTE` blocks for important design decisions

## Testbench Style (SystemVerilog .sv)
- **Headers**: Same as Verilog, include test case list in description
- **Clock gen**: `parameter CLK_PERIOD=20; forever #(CLK_PERIOD/2) clk=~clk;`
- **Test output**: 
  - Pass: `$display("PASS: Test %d - <description>", test_num);`
  - Fail: `$display("ERROR: Test %d - <description>", test_num); fail_count++;`
- **Waveforms**: `$dumpfile("tb_name.vcd"); $dumpvars(0, tb_name);` in initial block
- **Timeouts**: Use `fork-join_any` with `#timeout disable` pattern for UART tests
- **Test tracking**: Maintain `test_num`, `pass_count`, `fail_count`; print summary at end
- **Reset**: Assert `rstn=0` for 100ns, then release with `rstn=1`

## Architecture Notes
- **Memory map**: Slave1=2KB(0x000-0x7FF), Slave2=4KB(0x000-0xFFF), Slave3=4KB(split-capable)
- **Device addr**: Upper 4 bits select slave (2'b00=S1, 2'b01=S2, 2'b10=S3)
- **Arbitration**: M1 has priority over M2; split transactions allow bus release
- **UART protocol**: 21-bit frame for bus bridge (8b data, 12b addr, 1b R/W)
- **Signal protocol**: `mvalid`/`svalid` handshake; `breq`/`bgrant` for arbitration

## Key Files
- **Top**: `rtl/demo_uart_bridge.v` (DE0-Nano wrapper with KEY/SW/LED)
- **Bus core**: `rtl/core/bus_m2_s3.v` (2M3S interconnect, arbiter, decoder)
- **Arbiter**: `rtl/core/arbiter.v` (priority FSM with split support)
- **Bridge**: `rtl/core/bus_bridge_master.v`, `rtl/core/bus_bridge_slave.v`
- **Main TB**: `tb/master2_slave3_tb.sv` (comprehensive bus tests)
- **Demo TB**: `tb/tb_demo_uart_bridge.sv` (dual-system UART bridge)

## Error Handling
- **Sim**: Use `$display("ERROR: ...")` for failures; increment `fail_count`; call `$finish` after all tests
- **Synth**: Check `*.map.rpt`, `*.fit.rpt`, `*.sta.rpt` in `quartus/output_files/`
- **Timing**: Verify Fmax meets 50MHz target; check setup/hold slack in `*.sta.rpt`
- **Resource**: Target <50% ALM utilization for Cyclone V 5CSEBA6U23I7