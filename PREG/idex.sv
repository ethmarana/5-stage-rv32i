module idex (
    input logic clk,
    input logic reset,
    input logic flush,
    input logic [31:0] rd1D,
    input logic [31:0] rd2D,
    input logic [31:0] immD,
    input logic [31:0] pcD,
    input logic [31:0] pcplus4D,
    input logic [4:0] rs1D,
    input logic [4:0] rs2D,
    input logic [4:0] rdD,
    input logic [2:0] funct3D,
    input logic [2:0] immtypeD,
    input logic [3:0] alucontrolD,
    input logic [1:0] resultsrcD,
    input logic alusrcD,
    input logic srcaselD,
    input logic regwriteD,
    input logic memwriteD,
    input logic branchD,
    input logic jumpD,
    input logic validD,
    output logic [31:0] rd1E,
    output logic [31:0] rd2E,
    output logic [31:0] immE,
    output logic [31:0] pcE,
    output logic [31:0] pcplus4E,
    output logic [4:0] rs1E,
    output logic [4:0] rs2E,
    output logic [4:0] rdE,
    output logic [2:0] funct3E,
    output logic [2:0] immtypeE,
    output logic [3:0] alucontrolE,
    output logic [1:0] resultsrcE,
    output logic alusrcE,
    output logic srcaselE,
    output logic regwriteE,
    output logic memwriteE,
    output logic branchE,
    output logic jumpE,
    output logic validE
);

always_ff @(posedge clk) begin
    if (reset || flush) begin
        rd1E <= '0;
        rd2E <= '0;
        immE <= '0;
        pcE <= '0;
        pcplus4E <= '0;
        rs1E <= '0;
        rs2E <= '0;
        rdE <= '0;
        funct3E <= '0;
        immtypeE <= '0;
        alucontrolE <= '0;
        resultsrcE <= '0;
        alusrcE <= 1'b0;
        srcaselE <= 1'b0;
        regwriteE <= 1'b0;
        memwriteE <= 1'b0;
        branchE <= 1'b0;
        jumpE <= 1'b0;
        validE <= 1'b0;
    end else begin
        rd1E <= rd1D;
        rd2E <= rd2D;
        immE <= immD;
        pcE <= pcD;
        pcplus4E <= pcplus4D;
        rs1E <= rs1D;
        rs2E <= rs2D;
        rdE <= rdD;
        funct3E <= funct3D;
        immtypeE <= immtypeD;
        alucontrolE <= alucontrolD;
        resultsrcE <= resultsrcD;
        alusrcE <= alusrcD;
        srcaselE <= srcaselD;
        regwriteE <= regwriteD;
        memwriteE <= memwriteD;
        branchE <= branchD;
        jumpE <= jumpD;
        validE <= validD;
    end
end

endmodule