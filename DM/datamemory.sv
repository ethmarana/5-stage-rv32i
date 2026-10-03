module datamemory (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] datain,
    input logic dmwrite, 
    output logic [31:0] dmread
);

logic [31:0] memory [0:255]; 

always_ff @(posedge clk) begin
    if (dmwrite) begin
        memory[address[31:2]] <= datain;
    end 
end 

assign dmread = memory[address[31:2]];

endmodule 