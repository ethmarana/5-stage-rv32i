a new iteration of the preexisting RV32i processor, except pipelined

FPGA - > Zybo (OG) 

Target Clock: 125 MHz

WNS: +1.963 ns

TNS: 0.000 ns

WHS: +0.040 ns

THS: 0.000 ns

Estimated Critical Path: 6.037 ns

Estimated Fmax: ~166 MHz

Timing Endpoints 1084

Met timing at a 125 MHz target on an OG Zybo AMD, achieving +1.963 WNS with no violations. Estimated max clock frequency of ~166 MHz.

Microarchitecture Design choice: Used a mux controlled by srcasel to choose whether ALU operand A comes from rs1 or the PC. This allows instructions like AUIPC and JAL to reuse the main ALU instead of requiring a dedicated PC+immediate adder.

Tradeoff: Reusing the ALU can reduce hardware/resource usage, but adds a mux and control signal to the ALU input path. A separate adder uses more hardware, but can compute PC + immediate in parallel and may simplify/tighten timing for branch/jump logic.
