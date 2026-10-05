a new iteration of the preexisting RISC-V processor, except pipelined

RV32I


in control unit -> 
Design choice: Used a mux controlled by srcasel to choose whether ALU operand A comes from rs1 or the PC. This allows instructions like AUIPC and JAL to reuse the main ALU instead of requiring a dedicated PC+immediate adder.

Tradeoff: Reusing the ALU can reduce hardware/resource usage, but adds a mux and control signal to the ALU input path. A separate adder uses more hardware, but can compute PC + immediate in parallel and may simplify/tighten timing for branch/jump logic.
