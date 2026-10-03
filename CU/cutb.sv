module controlunit_tb;

logic [6:0] opcode;
logic [2:0] funct3;
logic funct7b5;

logic regwrite;
logic alusrc;
logic memwrite;
logic branch;
logic jump;
logic srcasel;
logic [1:0] resultsrc;
logic [2:0] immtype;
logic [3:0] alucontrol;

controlunit dut (
    .opcode(opcode),
    .funct3(funct3),
    .funct7b5(funct7b5),
    .regwrite(regwrite),
    .alusrc(alusrc),
    .memwrite(memwrite),
    .branch(branch),
    .jump(jump),
    .srcasel(srcasel),
    .resultsrc(resultsrc),
    .immtype(immtype),
    .alucontrol(alucontrol)
);

initial begin

    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (regwrite !== 1'b1 || alusrc !== 1'b0 || alucontrol !== 4'b0010)
        $error("R-type ADD failed");

    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7b5 = 1'b1;
    #1;
    if (regwrite !== 1'b1 || alucontrol !== 4'b0110)
        $error("R-type SUB failed");

    opcode = 7'b0010011;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (regwrite !== 1'b1 || alusrc !== 1'b1 || immtype !== 3'b000 || alucontrol !== 4'b0010)
        $error("I-type ADDI failed");

    opcode = 7'b0000011;
    funct3 = 3'b010;
    funct7b5 = 1'b0;
    #1;
    if (regwrite !== 1'b1 || alusrc !== 1'b1 || resultsrc !== 2'b01 || immtype !== 3'b000)
        $error("LOAD failed");

    opcode = 7'b0100011;
    funct3 = 3'b010;
    funct7b5 = 1'b0;
    #1;
    if (memwrite !== 1'b1 || alusrc !== 1'b1 || immtype !== 3'b001 || alucontrol !== 4'b0010)
        $error("STORE failed");

    opcode = 7'b1101111;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (jump !== 1'b1 || regwrite !== 1'b1 || srcasel !== 1'b1 || alusrc !== 1'b1 || resultsrc !== 2'b10 || immtype !== 3'b100)
        $error("JAL failed");

    opcode = 7'b1100111;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (jump !== 1'b1 || regwrite !== 1'b1 || alusrc !== 1'b1 || resultsrc !== 2'b10 || immtype !== 3'b000)
        $error("JALR failed");

    opcode = 7'b0110111;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (regwrite !== 1'b1 || resultsrc !== 2'b11 || immtype !== 3'b011)
        $error("LUI failed");

    opcode = 7'b0010111;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (regwrite !== 1'b1 || srcasel !== 1'b1 || alusrc !== 1'b1 || resultsrc !== 2'b00 || immtype !== 3'b011)
        $error("AUIPC failed");

    opcode = 7'b1100011;
    funct3 = 3'b000;
    funct7b5 = 1'b0;
    #1;
    if (branch !== 1'b1 || immtype !== 3'b010 || alucontrol !== 4'b0110)
        $error("BEQ failed");

    opcode = 7'b1100011;
    funct3 = 3'b100;
    funct7b5 = 1'b0;
    #1;
    if (branch !== 1'b1 || immtype !== 3'b010 || alucontrol !== 4'b0111)
        $error("BLT failed");

    $display("All control unit tests passed");
    $finish;

end

endmodule