module regfile #(parameter int dataw = 32, parameter int regamt = 32) (
    input logic clk,
    input logic regwrite,
    input logic reset,
    input logic [$clog2(regamt)-1:0] rs1,
    input logic [$clog2(regamt)-1:0] rs2,
    input logic [$clog2(regamt)-1:0] rd,
    input logic [dataw-1:0] writedata,
    output logic [dataw-1:0] rd1,
    output logic [dataw-1:0] rd2
);

logic [dataw-1:0] regs [0:regamt-1]; 

always_ff @(posedge clk) begin
    if (regwrite && rd != '0 && !reset) begin
        regs[rd] <= writedata; 
    end 
end

always_comb begin
    if (rs1 == '0) begin
        rd1 = '0;
    end else begin
        rd1 = regs[rs1];
    end

    if (rs2 == '0) begin
        rd2 = '0;
    end else begin
        rd2 = regs[rs2];
    end
end


endmodule 

