module controlunit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic funct7b5,
    output logic regwrite,
    // (input b) alusrc is the mux that decides if operand comes from registers or immgen
    output logic alusrc,
    output logic memwrite,
    output logic branch,
    output logic jump,
    // (input a) srcasel mux that decides if operand is register or PC
    output logic srcasel,
    output logic [1:0] resultsrc,
    output logic [2:0] immtype,
    output logic [3:0] alucontrol
);

typedef enum logic [6:0] {
    op_rtype = 7'b0110011,
    op_itype = 7'b0010011,
    op_load = 7'b0000011,
    op_store = 7'b0100011,
    op_jal = 7'b1101111,
    op_jalr = 7'b1100111,
    op_lui = 7'b0110111,
    op_auipc = 7'b0010111,
    op_branchop = 7'b1100011
} opcodes; 

typedef enum logic [2:0] {
    itype = 3'b000,
    stype = 3'b001,
    btype = 3'b010,
    utype = 3'b011,
    jtype = 3'b100
} itypes; 


typedef enum  logic [3:0] {
    AND  = 4'b0000,
    OR   = 4'b0001,
    ADD  = 4'b0010,
    XOR  = 4'b0011,
    SLL  = 4'b0100,
    SRL  = 4'b0101,
    SUB  = 4'b0110,
    SLT  = 4'b0111,
    SLTU = 4'b1000,
    SRA  = 4'b1001
} alu_ops; 

typedef enum logic [2:0] {
    BEQ = 3'b000,
    BNE = 3'b001,
    BLT = 3'b100,
    BGE = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
} branchcomparators; 

always_comb begin
    regwrite = 1'b0;
    alusrc = 1'b0;
    memwrite = 1'b0;
    branch = 1'b0;
    jump = 1'b0;
    resultsrc = 2'b0;
    immtype = 3'b0;
    alucontrol = 4'b0;
    srcasel = 1'b0; 

    case(opcode)
        op_rtype: begin
            // basic ALU ops thru registers
            regwrite = 1'b1;
            alusrc = 1'b0;
            resultsrc = 2'b00;

        case (funct3)
            3'b111: alucontrol = AND;
            3'b110: alucontrol = OR;
            3'b100: alucontrol = XOR;
            3'b001: alucontrol = SLL;
            3'b101: begin
                if (funct7b5)
                alucontrol = SRA;
                else
                    alucontrol = SRL;
            end
            3'b010: alucontrol = SLT;
            3'b011: alucontrol = SLTU;
            3'b000: begin
                if (funct7b5)
                    alucontrol = SUB;
                else
                    alucontrol = ADD;
            end
            default: begin
            end 
        endcase

        end 

        op_itype: begin
            //basically same as r type just uses immediate
            immtype = itype;
            regwrite = 1'b1;
            alusrc = 1'b1;
            resultsrc = 2'b0;
            case (funct3)
                3'b111: alucontrol = AND;
                3'b110: alucontrol = OR;
                3'b100: alucontrol = XOR;
                3'b001: alucontrol = SLL;
                3'b101: begin
                if (funct7b5)
                    alucontrol = SRA;
                else
                    alucontrol = SRL;
                end

            3'b010: alucontrol = SLT;
            3'b011: alucontrol = SLTU;
            // RV32i there is no immediate subtract u just use a negative #
            //so no if statement needed
            3'b000: alucontrol = ADD;
            default: begin
            end 
            endcase
        end 

        op_load: begin
            // reads x2 adds 8 to get memory address to read then store to rd
            immtype = itype;
            alusrc = 1'b1;
            alucontrol = ADD; 
            regwrite = 1'b1; 
            resultsrc = 2'b01; 
        end

        op_store: begin
            // stores rs2 into memory at address (rs1 + immediate)
            immtype = stype; 
            memwrite = 1'b1;
            alucontrol = ADD;
            alusrc = 1'b1; 
        end

        op_jal: begin
            // jumps the PC by adding from PC, then stores the adress where it jumped from 
            immtype = jtype;
            alucontrol = ADD;
            srcasel = 1'b1;
            alusrc = 1'b1; 
            jump = 1'b1;
            regwrite = 1'b1; 
            resultsrc = 2'b10;
        end 

        op_jalr: begin
            // jump target = rs1 + immediate, saves PC + 4 in rd
            immtype = itype;
            alucontrol = ADD;
            regwrite = 1'b1;
            jump = 1'b1; 
            alusrc = 1'b1;
            resultsrc = 2'b10; 
        end 

        op_lui: begin  
            // load the upper of a register with 20 bits
            immtype = utype; 
            regwrite = 1'b1;
            resultsrc = 2'b11; 
        end 

        op_auipc: begin
            // add upper immediate to the PC
            immtype = utype;
            alusrc = 1'b1;
            regwrite = 1'b1;
            alucontrol = ADD;
            resultsrc = 2'b00;
            srcasel = 1'b1;
        end 

        op_branchop: begin
            //basically conditional jump / decides which branch type
            immtype = btype;
            branch = 1'b1;
            case(funct3)
                BEQ: begin
                    alucontrol = SUB;
                end 
                    
                BNE: begin
                    alucontrol = SUB;
                end 

                BLT: begin
                    alucontrol = SLT;
                end

                BGE: begin
                    alucontrol = SLT;
                end 

                BLTU: begin
                    alucontrol = SLTU;
                end

                BGEU: begin
                    alucontrol = SLTU;
                end 
                default: begin
                end 
            endcase 
        end 

    endcase
    
end 


endmodule 




