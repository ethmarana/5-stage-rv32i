module immediategenerator #() (
    input logic [31:0] instr, 
    input logic [2:0] immtype,
    output logic [31:0] imm
);

typedef enum logic [2:0] {
    itype = 3'b000,
    stype = 3'b001,
    btype = 3'b010,
    utype = 3'b011,
    jtype = 3'b100
} itypes; 

always_comb begin
    case(immtype)
//just use a constant in instruction ratherr than register
        itype: begin
            imm = {{20{instr[31]}}, instr[31:20]}; 
        end 
//store 
        stype: begin
            imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end 
//branch offsets in program counter / can only be mults of 2 so lsb is always 0 / short jumps / conditional 
        btype: begin
            imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        end 
// upper part of a big number, the lower 12 bits are then adjusted in a seperate instr
        utype: begin
            imm = {instr[31:12], 12'b0};
        end 
// unconditional, longer jumps than B type / imm[0] also is 0 for same purpose as b-type
        jtype: begin
            imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}};
        end 
        default: begin
            imm = 32'b0;
        end 

    endcase 

end 



endmodule 

