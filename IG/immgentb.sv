module immediategenerator_tb;

logic [31:0] instr;
logic [2:0] immtype;
logic [31:0] imm;

immediategenerator dut (
    .instr(instr),
    .immtype(immtype),
    .imm(imm)
);

initial begin

    immtype = 3'b000;
    instr = 32'b00000000101000000000000000000000;
    #1;
    if (imm !== 32'd10) $error("I-type failed");

    immtype = 3'b001;
    instr = 32'b00000000000000000000010100000000;
    #1;
    if (imm !== 32'd10) $error("S-type failed");

    immtype = 3'b010;
    instr = 32'b00000000000000000000010000000000;
    #1;
    if (imm !== 32'd8) $error("B-type failed");

    immtype = 3'b011;
    instr = 32'h12345000;
    #1;
    if (imm !== 32'h12345000) $error("U-type failed");

    immtype = 3'b100;
    instr = 32'b00000000100000000000000000000000;
    #1;
    if (imm !== 32'd8) $error("J-type failed");

    $display("All tests passed");
    $finish;

end

endmodule