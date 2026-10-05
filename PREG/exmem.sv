module exmem (
    input logic clk,
    input logic reset,
    input logic [31:0] alu_resultE,
    input logic [31:0] storedataE,
    input logic [31:0] pcplus4E,
    input logic [31:0] immE,
    input logic [4:0] rdE,
    input logic [1:0] resultsrcE,
    input logic regwriteE,
    input logic memwriteE,
    input logic validE,
    output logic [31:0] alu_resultM,
    output logic [31:0] storedataM,
    output logic [31:0] pcplus4M,
    output logic [31:0] immM,
    output logic [4:0] rdM,
    output logic [1:0] resultsrcM,
    output logic regwriteM,
    output logic memwriteM,
    output logic validM
);

always_ff @(posedge clk) begin
    if (reset) begin
        alu_resultM <= '0;
        storedataM <= '0;
        pcplus4M <= '0;
        immM <= '0;
        rdM <= '0;
        resultsrcM <= '0;
        regwriteM <= 1'b0;
        memwriteM <= 1'b0;
        validM <= 1'b0;
    end else begin
        alu_resultM <= alu_resultE;
        storedataM <= storedataE;
        pcplus4M <= pcplus4E;
        immM <= immE;
        rdM <= rdE;
        resultsrcM <= resultsrcE;
        regwriteM <= regwriteE;
        memwriteM <= memwriteE;
        validM <= validE;
    end
end

endmodule