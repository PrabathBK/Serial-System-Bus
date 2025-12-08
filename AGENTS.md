# AGENTS.md - ADS Serial Bus System

## Build/Test Commands
- **Synthesis**: `./scripts/synthesize_and_verify.sh` (Quartus: map, fit, asm, sta)
- **Full sim**: `./sim/run_sim.sh` (Vivado xsim, master2_slave3_tb.sv)
- **Single test**: `./sim/run_simple_test.sh` (simple_read_test.sv)
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`

## Code Style (Verilog)
- **Timescale**: `` `timescale 1ns / 1ps `` at top of each file
- **Naming**: modules/signals `lowercase_underscore`, parameters `UPPER_CASE`
- **Reset**: Active-low `rstn`, async: `always @(posedge clk or negedge rstn)`
- **Ports**: `input wire`, `output reg` for registered; FSM: separate comb (`always @(*)`) and seq blocks
- **States**: `localparam IDLE = 3'b000, STATE1 = 3'b001;`
- **Headers**: Module name, description, target (Intel Cyclone IV EP4CE22F17C6)

## Testbench Style (SystemVerilog .sv)
- Clock: `forever #(CLK_PERIOD/2) clk = ~clk;`
- Output: `$display("PASS: ...")` or `$display("ERROR: ...")`; VCD via `$dumpfile`/`$dumpvars`
- Timeout: `initial begin #1000000; $display("Timeout!"); $finish; end`

## Key Files
- **Top-level**: `rtl/demo_uart_bridge.v` (DE0-Nano UART bridge)
- **Testbenches**: `tb_arbiter.sv` (Task 2), `tb_addr_decoder.sv` (Task 3), `master2_slave3_tb.sv` (Task 4)

Update todo.md and AGENTS.md always