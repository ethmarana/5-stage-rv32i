module programcounter (
    input logic clk,
    input logic reset,
    input logic enable, 
    input logic [31:0] pc_next,    
    output logic [31:0] pc
);

always_ff @(posedge clk) begin
    if (reset) begin 
        pc <= 32'b0;
    end else if (enable) begin
        pc <= pc_next; 
    end 

end 
  

endmodule