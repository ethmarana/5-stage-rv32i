module ALU #(parameter int dataw = 32) (
    input logic [dataw-1:0] a,
    input logic [dataw-1:0] b,
    input logic [3:0] control,
    output logic [dataw-1:0] result,
    output logic zero
);

typedef enum  logic [3:0] {
    AND  = 4'b0000,
    OR   = 4'b0001,
    ADD  = 4'b0010, 
    XOR  = 4'b0011,
    SLL  = 4'b0100,
    SRL  = 4'b0101,
    SUB  = 4'b0110,
    SLT  = 4'b0111,
    SLTU = 4'b1000,
    SRA  = 4'b1001
} alu_ops; 

always_comb begin
    case (control)
        AND:
            result = a & b;
        OR:
            result = a | b;
        ADD:
            result = a + b;
        XOR:
            result = a ^ b;
        SLL:
            result = a << b[4:0];
        SRL:
            result = a >> b[4:0];
        SUB:
            result = a - b;
        SLT:
            result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
        SLTU:
            result = (a < b) ? 32'd1 : 32'd0;
        SRA:
            result = $signed(a) >>> b[4:0];
        default:
            result = 32'b0;
        endcase

        zero = (result == 32'b0);
    end

endmodule