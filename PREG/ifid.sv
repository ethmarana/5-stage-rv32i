module ifid (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic flush,
    input logic [31:0] instrF,
    input logic [31:0] pcF,
    input logic [31:0] pcplus4F, 
    output logic [31:0] instrD,
    output logic [31:0] pcD,
    output logic [31:0] pcplus4D,
    output logic validD
);

always_ff @(posedge clk) begin
    if (reset || flush) begin 
        instrD <= '0;
        pcD <= '0;
        pcplus4D <= '0;
        validD <= 1'b0;
    end else if (enable) begin
        instrD <= instrF;
        pcD <= pcF;
        pcplus4D <= pcplus4F;
        validD <= 1'b1;
    end 

end 

endmodule 