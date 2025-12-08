### Assignment

- Top level design: Design a serial bus
- RTL Integration
- 2 Masters \& 3 slaves with 4K (Split supported), 4K \& 2K
- RTL with async reset \& posedeg clocks
- **Implement your design in DE0 board**

Task

1. Arbiter Design : Priority based, split transaction, \& IO definition (commented)

2. Arbiter Verification : Reset test, single master request \& 2 master requests, \& split transaction viable scenario

3. Address decoder : Address decoder verification, 3 slaves, address mapping, reset test, \& slave select

4. Top level verification : a) Reset test, b) one master request, c) two master requests, and d) split transaction viable scenario

5. Bus bridge setup that could connect to external device (another FPGA) through UART to communicate and write to its (second FPGA) slave
