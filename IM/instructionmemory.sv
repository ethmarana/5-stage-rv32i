module instructionmemory (
    input logic [31:0] address,
    output logic [31:0] instr
);

logic [31:0] memory [0:255]; 

initial begin
    $readmemh("program.hex", memory);
    //program hex contains: 
    // addi x1, x0, 5 00500093 
    // addi x2, x0, 3 00300113 
    // add x3, x1, x2 002081b3 
    // end forever loop 0000006f 
end 

assign instr = memory[address[31:2]];

endmodule