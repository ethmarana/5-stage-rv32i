module hazard (
    input logic [4:0] rs1D,
    input logic [4:0] rs2D, 
    input logic uses_rs1D,
    input logic uses_rs2D,
    input logic [4:0] rdE,
    input logic isloadE,
    input logic redirectE,
    output logic stallF,
    output logic stallD,
    output logic flushD,
    output logic flushE
);

// f = IF | d = ID | E = ex | M = mem | W = wb 

always_comb begin
    stallF = '0;
    stallD = '0;
    flushD = '0;
    flushE = '0;
    // if were using and loading a reg at the same time IF is stalled in order to give time for register to update to final value 
    if (uses_rs1D && (rs1D == rdE) && isloadE && rdE != 5'b0) begin
        stallF = 1'b1;
        stallD = 1'b1;
        flushE = 1'b1;
    end 
    if (uses_rs2D && (rs2D == rdE) && isloadE && rdE != 5'b0) begin
        stallF = 1'b1;
        stallD = 1'b1;
        flushE = 1'b1;
    end 
    //if theres a valid branch, jal, or jalr the instruction path moves to a new spot, so the last 2 instructions are not correct so they are flushed 
    if (redirectE) begin
        stallF = '0;
        stallD = '0;
        flushD = 1'b1;
        flushE = 1'b1;
    end


end 

endmodule 