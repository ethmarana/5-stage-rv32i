module ALU_tb;

    logic [31:0] a;
    logic [31:0] b;
    logic [3:0] control;
    logic [31:0] result;
    logic zero;

ALU #(.dataw(32)) instance1 (
    .a(a),
    .b(b),
    .control(control),
    .result(result),
    .zero(zero)
);

initial begin 
    // test case bitwise AND
    a = 32'b00000000000000000000000000001111;
    b = 32'b00000000000000000000000000000101;
    control = 4'b0000;
    #33;
    if (result == 32'b00000000000000000000000000000101 && zero == 1'b0) begin
        $display("AND passed");
    end else begin
        $display("AND failed");
    end

    // test case bitwise OR
    a = 32'b00000000000000000000000000001111;
    b = 32'b00000000000000000000000000000101;
    control = 4'b0001;
    #33;
    if (result == 32'b00000000000000000000000000001111 && zero == 1'b0) begin
        $display("OR passed");
    end else begin
        $display("OR failed");
    end

    // test case add 
    a = 32'd16;
    b = 32'd32;
    control = 4'b0010;
    #33;
    if (result == 32'd48 && zero == 1'b0) begin
        $display("ADD passed");
    end else begin
        $display("ADD failed");
    end

    // test case bitwise XOR
    a = 32'b00000000000000000000000000001111;
    b = 32'b00000000000000000000000000000101;
    control = 4'b0011;
    #33;
    if (result == 32'b00000000000000000000000000001010 && zero == 1'b0) begin
        $display("XOR passed");
    end else begin
        $display("XOR failed");
    end

    // test case shift left logical
    a = 32'd1;
    b = 32'd4;
    control = 4'b0100;
    #33;
    if (result == 32'd16 && zero == 1'b0) begin
        $display("SLL passed");
    end else begin
        $display("SLL failed");
    end

    // test case shift right logical
    a = 32'd32;
    b = 32'd2;
    control = 4'b0101;
    #33;
    if (result == 32'd8 && zero == 1'b0) begin
        $display("SRL passed");
    end else begin
        $display("SRL failed");
    end

    // test case subtract
    a = 32'd105;
    b = 32'd66;
    control = 4'b0110;
    #33;
    if (result == 32'd39 && zero == 1'b0) begin
        $display("SUBTRACT passed");
    end else begin  
        $display("SUBTRACT failed");
    end

    // test case set less than
    a = 32'd152;
    b = 32'd272;
    control = 4'b0111;
    #33;
    if (result == 32'd1 && zero == 1'b0) begin
        $display("SLT passed");
    end else begin
        $display("SLT failed");
    end

    // test case set less than unsigned
    a = 32'd5;
    b = 32'd16;
    control = 4'b1000;
    #33;
    if (result == 32'd1 && zero == 1'b0) begin
        $display("SLTU passed");
    end else begin
        $display("SLTU failed");
    end

    // test case shift right arithmetic
    a = 32'd4294967280;
    b = 32'd2;
    control = 4'b1001;
    #33;
    if (result == 32'd4294967292 && zero == 1'b0) begin
        $display("SRA passed");
    end else begin
        $display("SRA failed");
    end

    // test case default 
    control = 4'b1111;
    #33;
    if (result == 32'b0 && zero == 1'b1) begin
        $display("DEFAULT passed");
    end else begin
        $display("DEFAULT failed");
    end 

    // test case zero
    a = 32'd5;
    b = 32'd5;
    control = 4'b0110;
    #33;
    if (result == 32'b0 && zero == 1'b1) begin
        $display("ZERO passed");
    end else begin
        $display("ZERO failed");
    end
    
    $finish;
end 


endmodule