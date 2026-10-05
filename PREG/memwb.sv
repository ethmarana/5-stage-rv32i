module memwb (
    input logic clk,
    input logic reset,
    input logic [31:0] alu_resultM,
    input logic [31:0] dmreadM,
    input logic [31:0] pcplus4M,
    input logic [31:0] immM,
    input logic [4:0] rdM,
    input logic [1:0] resultsrcM,
    input logic regwriteM,
    input logic validM,
    output logic [31:0] alu_resultW,
    output logic [31:0] dmreadW,
    output logic [31:0] pcplus4W,
    output logic [31:0] immW,
    output logic [4:0] rdW,
    output logic [1:0] resultsrcW,
    output logic regwriteW,
    output logic validW
);

always_ff @(posedge clk) begin
    if (reset) begin
        alu_resultW <= '0;
        dmreadW <= '0;
        pcplus4W <= '0;
        immW <= '0;
        rdW <= '0;
        resultsrcW <= '0;
        regwriteW <= 1'b0;
        validW <= 1'b0;
    end else begin
        alu_resultW <= alu_resultM;
        dmreadW <= dmreadM;
        pcplus4W <= pcplus4M;
        immW <= immM;
        rdW <= rdM;
        resultsrcW <= resultsrcM;
        regwriteW <= regwriteM;
        validW <= validM;
    end
end

endmodule