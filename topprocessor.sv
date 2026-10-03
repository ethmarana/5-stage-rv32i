module tpross (
    input logic clk,
    input logic reset
);

logic [31:0] instr; 
logic [6:0] opcode;
logic [2:0] funct3;
logic funct7b5;
logic regwrite;
logic alusrc;
logic memwrite;
logic branch;
logic jump;
logic srcasel;
logic aluzeroflag;
logic [1:0] resultsrc;
logic [2:0] immtype;
logic [3:0] alucontrol;
logic [4:0] rs1;
logic [4:0] rs2;
logic [4:0] rd; 
logic [31:0] rd1;
logic [31:0] rd2;
logic [31:0] alu_result; 
logic [31:0] pc; 
logic [31:0] imm; 
logic [31:0] pc_next; 
logic [31:0] writedata;
logic [31:0] dmread; 


// for muxes
logic [31:0] rd1orpc;
logic [31:0] rd2orimm;

assign rd1orpc = srcasel ? pc : rd1;
assign rd2orimm = alusrc ? imm : rd2;
assign pc_next = pc + 4; 
assign opcode = instr[6:0];
assign funct3 = instr[14:12];
assign funct7b5 = instr[30];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign rd = instr[11:7];

programcounter pcinstance (.clk(clk), .reset(reset), .pc_next(pc_next), .pc(pc));
alu aluinstance (.a(rd1orpc), .b(rd2orimm), .control(alucontrol), .result(alu_result), .zero(aluzeroflag)); 
immediategenerator iginstance (.instr(instr), .immtype(immtype), .imm(imm));
controlunit cuinstance (
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
instructionmemory iminstance (.address(pc), .instr(instr));
registerfile rfinstance (.clk(clk), .regwrite(regwrite), .rs1(rs1), .rs2(rs2), .rd(rd), .writedata(writedata), .rd1(rd1), .rd2(rd2));
datamemory dminstance (.clk(clk), .address(alu_result), .datain(rd2), .dmwrite(memwrite), .dmread(dmread));

endmodule 