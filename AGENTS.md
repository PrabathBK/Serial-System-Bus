# AGENTS.md - ADS Serial Bus System

## Build/Synthesis Commands
- **Quartus synthesis**: `./scripts/synthesize_and_verify.sh` (phases: map, fit, asm, sta)
- **Simulation (full test)**: `./sim/run_sim.sh` (Vivado xsim, runs master2_slave3_tb.sv)
- **Single test**: `./sim/run_simple_test.sh` (runs simple_read_test.sv)
- **FPGA program**: `quartus_pgm -m jtag -o "p;quartus/output_files/ads_bus_system.sof@1"`

## Code Style Guidelines
- **Timescale**: `` `timescale 1ns / 1ps ``
- **Naming**: modules/signals lowercase_underscore (`slave_port`), parameters UPPER_CASE (`ADDR_WIDTH`)
- **Reset**: Active-low `rstn`, async pattern: `always @(posedge clk or negedge rstn)`
- **Ports**: Use `input wire`, explicit `output reg` for registered outputs
- **FSM**: Separate combinational next-state (`always @(*)`) and sequential transition (`always @(posedge clk or negedge rstn)`)
- **State encoding**: `localparam IDLE = 3'b000, STATE1 = 3'b001;`
- **File header**: Module name, description, parameters, target device (Intel Cyclone IV EP4CE22F17C6)
- **Section dividers**: `//--------------------------------------------------------------------------`

## Testbench Style
- SystemVerilog (.sv), clock with `forever #(CLK_PERIOD/2) clk = ~clk;`
- Use `$dumpfile`/`$dumpvars` for VCD, `$display` with PASS:/ERROR: prefixes
- Timeout watchdog: `initial begin #1000000; $display("Timeout!"); $finish; end`

## Top-Level Module
- **demo_uart_bridge.v**: Main top-level for DE0-Nano with UART bridge support

## Testbenches (tb/)
| Testbench | Assignment Task | Description |
|-----------|-----------------|-------------|
| `tb_arbiter.sv` | Task 2 | Arbiter verification: reset, single/dual master, split |
| `tb_addr_decoder.sv` | Task 3 | Address decoder: reset, 3 slaves, address mapping, slave select |
| `master2_slave3_tb.sv` | Task 4 | Top-level: reset, 1/2 master requests, split transaction |
| `simple_read_test.sv` | - | Debug testbench for basic read/write verification |
