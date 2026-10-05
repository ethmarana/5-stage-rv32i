module tpross (
    input logic clk,
    input logic reset
);


// IF stage
logic [31:0] pcF;
logic [31:0] pcplus4F;
logic [31:0] pc_nextF;
logic [31:0] instrF;

// ID stage
logic [31:0] instrD;
logic [31:0] pcD;
logic [31:0] pcplus4D;
logic [31:0] rd1D;
logic [31:0] rd2D;
logic [31:0] immD;
logic [4:0] rs1D;
logic [4:0] rs2D;
logic [4:0] rdD;
logic [6:0] opcodeD;
logic [2:0] funct3D;
logic funct7b5D;
logic [2:0] immtypeD;
logic [3:0] alucontrolD;
logic [1:0] resultsrcD;
logic alusrcD;
logic srcaselD;
logic regwriteD;
logic memwriteD;
logic branchD;
logic jumpD;
logic validD;
logic uses_rs1D;
logic uses_rs2D;

// Register-file read outputs before WB-to-ID bypass
logic [31:0] rd1rawD;
logic [31:0] rd2rawD;

// EX stage
logic [31:0] rd1E;
logic [31:0] rd2E;
logic [31:0] immE;
logic [31:0] pcE;
logic [31:0] pcplus4E;
logic [4:0] rs1E;
logic [4:0] rs2E;
logic [4:0] rdE;
logic [2:0] funct3E;
logic [2:0] immtypeE;
logic [3:0] alucontrolE;
logic [1:0] resultsrcE;
logic alusrcE;
logic srcaselE;
logic regwriteE;
logic memwriteE;
logic branchE;
logic jumpE;
logic validE;
logic isloadE;

// EX forwarding and ALU inputs
logic [31:0] rd1forwardE;
logic [31:0] rd2forwardE;
logic [31:0] rd1orpcE;
logic [31:0] rd2orimmE;
logic [31:0] alu_resultE;
logic aluzeroflagE;

// EX branch and jump logic
logic [31:0] pctargetE;
logic branchcontrueE;
logic redirectE;

// MEM stage
logic [31:0] alu_resultM;
logic [31:0] storedataM;
logic [31:0] pcplus4M;
logic [31:0] immM;
logic [31:0] dmreadM;
logic [4:0] rdM;
logic [1:0] resultsrcM;
logic regwriteM;
logic memwriteM;
logic validM;

// MEM-stage result available for forwarding
logic [31:0] resultM;

// WB stage
logic [31:0] alu_resultW;
logic [31:0] dmreadW;
logic [31:0] pcplus4W;
logic [31:0] immW;
logic [31:0] resultW;
logic [4:0] rdW;
logic [1:0] resultsrcW;
logic regwriteW;
logic validW;

// Hazard and forwarding controls
logic stallF;
logic stallD;
logic flushD;
logic flushE;

// Valid-gated write enables
logic rf_write_enable;
logic dm_write_enable;

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//hazard handling (scary)
hazard huinstnace (
    .rs1D(rs1D), 
    .rs2D(rs2D), 
    .uses_rs1D(uses_rs1D), 
    .uses_rs2D(uses_rs2D),
    .rdE(rdE),
    .isloadE(isloadE),
    .redirectE(redirectE),
    .stallF(stallF),
    .stallD(stallD),
    .flushD(flushD),
    .flushE(flushE)
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//if stage (instruction fetch)
programcounter pcinstance (.clk(clk), .reset(reset), .enable(!stallF), .pc_next(pc_nextF), .pc(pcF));

instructionmemory iminstance (.address(pcF), .instr(instrF));

assign pcplus4F = pcF + 32'd4;
assign pc_nextF = redirectE ? pctargetE : pcplus4F; 

ifid ifidinstance (
    .clk(clk),
    .reset(reset),
    .enable(!stallD),
    .flush(flushD),
    .instrF(instrF),
    .pcF(pcF),
    .pcplus4F(pcplus4F),
    .instrD(instrD),
    .pcD(pcD),
    .pcplus4D(pcplus4D),
    .validD(validD)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//id stage (instruction decode) 
assign opcodeD = instrD[6:0];
assign funct3D = instrD[14:12];
assign funct7b5D = instrD[30];
assign rs1D = instrD[19:15];
assign rs2D = instrD[24:20];
assign rdD = instrD[11:7];
assign rf_write_enable = validW && regwriteW; 

//if WB is writing on same register that is being used, use the writeback value instead of the one currently stored in reg

assign rd1D = (rf_write_enable && rdW != 5'b0 && rdW == rs1D)
    ? resultW : rd1rawD;

assign rd2D = (rf_write_enable && rdW != 5'b0 && rdW == rs2D)
    ? resultW : rd2rawD;

controlunit cuinstance (
    .opcode(opcodeD),
    .funct3(funct3D), 
    .funct7b5(funct7b5D), 
    .regwrite(regwriteD), 
    .alusrc(alusrcD), 
    .memwrite(memwriteD), 
    .branch(branchD), 
    .jump(jumpD),
    .srcasel(srcaselD),
    .resultsrc(resultsrcD),
    .immtype(immtypeD),
    .alucontrol(alucontrolD)
);

immediategenerator iginstance (
    .instr(instrD),
    .immtype(immtypeD),
    .imm(immD)
);

regfile rfinstance (
    .clk(clk), 
    .regwrite(rf_write_enable), 
    .reset(reset), 
    .rs1(rs1D), 
    .rs2(rs2D), 
    .rd(rdW), 
    .writedata(resultW), 
    .rd1(rd1rawD), 
    .rd2(rd2rawD)
);

idex idexinstance (
    .clk(clk),
    .reset(reset),
    .flush(flushE),
    .rd1D(rd1D),
    .rd2D(rd2D),
    .immD(immD),
    .pcD(pcD),
    .pcplus4D(pcplus4D),
    .rs1D(rs1D),
    .rs2D(rs2D),
    .rdD(rdD),
    .funct3D(funct3D),
    .immtypeD(immtypeD),
    .alucontrolD(alucontrolD),
    .resultsrcD(resultsrcD),
    .alusrcD(alusrcD),
    .srcaselD(srcaselD),
    .regwriteD(regwriteD),
    .memwriteD(memwriteD),
    .branchD(branchD),
    .jumpD(jumpD),
    .validD(validD),
    .rd1E(rd1E),
    .rd2E(rd2E),
    .immE(immE),
    .pcE(pcE),
    .pcplus4E(pcplus4E),
    .rs1E(rs1E),
    .rs2E(rs2E),
    .rdE(rdE),
    .funct3E(funct3E),
    .immtypeE(immtypeE),
    .alucontrolE(alucontrolE),
    .resultsrcE(resultsrcE),
    .alusrcE(alusrcE),
    .srcaselE(srcaselE),
    .regwriteE(regwriteE),
    .memwriteE(memwriteE),
    .branchE(branchE),
    .jumpE(jumpE),
    .validE(validE)
);


//helps hazard unit know which registers are being used 
always_comb begin
    uses_rs1D = 1'b0;
    uses_rs2D = 1'b0;

    case (opcodeD)
        //r, store, branch use both registers
        7'b0110011, 7'b0100011, 7'b1100011: begin
            uses_rs1D = validD;
            uses_rs2D = validD;
        end
       //i, alu, load, and jalr use first register 
        7'b0010011, 7'b0000011, 7'b1100111: begin
            uses_rs1D = validD;
        end

        default: begin
        end
    endcase
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//ex stage (execution)

//mux to decide which values are a and b based on what instruction from ID 
assign rd1orpcE = srcaselE ? pcE : rd1forwardE;
assign rd2orimmE = alusrcE ? immE : rd2forwardE;

//decides which value to use for the registers, based on if mem or wb have a new value for it
always_comb begin
    rd1forwardE = rd1E;
    rd2forwardE = rd2E;
//loadwrite check added to prevent forwarding a load's address as its loaded value 
    if (validM && regwriteM && rdM != 5'b0 && rdM == rs1E) begin
        if (resultsrcM != LOADWRITE) begin
            rd1forwardE = resultM;
        end
    end else if (validW && regwriteW && rdW != 5'b0 && rdW == rs1E) begin
        rd1forwardE = resultW;
    end

    if (validM && regwriteM && rdM != 5'b0 && rdM == rs2E) begin
        if (resultsrcM != LOADWRITE) begin
            rd2forwardE = resultM;
        end
    end else if (validW && regwriteW && rdW != 5'b0 && rdW == rs2E) begin
        rd2forwardE = resultW;
    end
end

always_comb begin
    branchcontrueE = 1'b0;

    case (funct3E)
        BEQ: branchcontrueE = aluzeroflagE;
        BNE: branchcontrueE = !aluzeroflagE;
        BLT, BLTU: branchcontrueE = !aluzeroflagE;
        BGE, BGEU: branchcontrueE = aluzeroflagE;
        default: branchcontrueE = 1'b0;
    endcase
end

//decides between JALR or JAL and branches then calculates the jump address 
assign pctargetE = (jumpE && immtypeE == itype)
    ? ((rd1forwardE + immE) & 32'hFFFFFFFE)
    : (pcE + immE);

//decides if its valid to jump 
assign redirectE = validE && (jumpE || (branchE && branchcontrueE));
assign isloadE = validE && regwriteE && (resultsrcE == LOADWRITE);

ALU aluinstance (.a(rd1orpcE), .b(rd2orimmE), .control(alucontrolE), .result(alu_resultE), .zero(aluzeroflagE)); 

exmem exmeminstance (
    .clk(clk),
    .reset(reset),
    .alu_resultE(alu_resultE),
    .storedataE(rd2forwardE),
    .pcplus4E(pcplus4E),
    .immE(immE),
    .rdE(rdE),
    .resultsrcE(resultsrcE),
    .regwriteE(regwriteE),
    .memwriteE(memwriteE),
    .validE(validE),
    .alu_resultM(alu_resultM),
    .storedataM(storedataM),
    .pcplus4M(pcplus4M),
    .immM(immM),
    .rdM(rdM),
    .resultsrcM(resultsrcM),
    .regwriteM(regwriteM),
    .memwriteM(memwriteM),
    .validM(validM)
);

// mem stage (memory)

assign dm_write_enable = validM && memwriteM; 

datamemory dminstance (.clk(clk), .reset(reset), .address(alu_resultM), .datain(storedataM), .dmwrite(dm_write_enable), .dmread(dmreadM));


//forward mux selects reg result for possible forwarding to ex 
always_comb begin
    case (resultsrcM)
        ALUWRITE: resultM = alu_resultM;
        JUMPWRITE: resultM = pcplus4M;
        LUIWRITE: resultM = immM;
        default: resultM = 32'b0;
    endcase
end

memwb memwbinstance (
    .clk(clk),
    .reset(reset),
    .alu_resultM(alu_resultM),
    .dmreadM(dmreadM),
    .pcplus4M(pcplus4M),
    .immM(immM),
    .rdM(rdM),
    .resultsrcM(resultsrcM),
    .regwriteM(regwriteM),
    .validM(validM),
    .alu_resultW(alu_resultW),
    .dmreadW(dmreadW),
    .pcplus4W(pcplus4W),
    .immW(immW),
    .rdW(rdW),
    .resultsrcW(resultsrcW),
    .regwriteW(regwriteW),
    .validW(validW)
);

// wb stage (writeback)

//mux that decides what gets written back 
always_comb begin
    case (resultsrcW)
        ALUWRITE: resultW = alu_resultW;
        JUMPWRITE: resultW = pcplus4W;
        LUIWRITE: resultW = immW;
        LOADWRITE: resultW = dmreadW; 
        default: resultW = 32'b0;
    endcase
end



endmodule 
