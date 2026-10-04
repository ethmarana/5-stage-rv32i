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

typedef enum logic [2:0] {
    itype = 3'b000,
    stype = 3'b001,
    btype = 3'b010,
    utype = 3'b011,
    jtype = 3'b100
} itypes; 

typedef enum logic [1:0] {
    ALUWRITE = 2'b00,
    LOADWRITE = 2'b01,
    JUMPWRITE = 2'b10,
    LUIWRITE = 2'b11
} writebackmuxtype;

typedef enum logic [2:0] {
    BEQ = 3'b000,
    BNE = 3'b001,
    BLT = 3'b100,
    BGE = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
} branchcomparators; 

// for muxes
logic [31:0] rd1orpc;
logic [31:0] rd2orimm;
//muxes 
assign rd1orpc = srcasel ? pc : rd1;
assign rd2orimm = alusrc ? imm : rd2;

//writeback mux 
always_comb begin
    case(resultsrc)

        ALUWRITE: begin
            writedata = alu_result; 
        end 

        LOADWRITE: begin
            writedata = dmread; 
        end 

        JUMPWRITE: begin
            writedata = pc + 4; 
        end 

        LUIWRITE: begin
            writedata = imm; 
        end 

        default: begin
            writedata = 32'b0; 
        end 

    endcase 
end 

//pc_next logic
always_comb begin
    pc_next = pc + 4;
    // jal 
    if (immtype == jtype && jump) begin
        pc_next = pc + imm; 
    end else if (jump && immtype == itype) begin
        // jalr, bit 0 is forced to 0 per ISA
        pc_next = (rd1 + imm) & 32'hFFFFFFFE; 
    end else if (branch) begin
        case(funct3) 
            BEQ: begin
                if (aluzeroflag) begin
                    pc_next = pc + imm; 
                end 
            end 

            BNE: begin
                if (!aluzeroflag) begin
                    pc_next = pc + imm; 
                end 
            end 

            BLT: begin
                if (!aluzeroflag) begin
                    pc_next = pc + imm;
                end 
            end 

            BGE: begin
                if (aluzeroflag) begin
                    pc_next = pc + imm;
                end 
            end 

            BLTU: begin
                if (!aluzeroflag) begin
                    pc_next = pc + imm; 
                end 
            end 

            BGEU: begin
                if (aluzeroflag) begin
                    pc_next = pc + imm; 
                end 
            end 

        endcase 
    end 
end 




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