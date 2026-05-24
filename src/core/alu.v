module alu (
    input wire [7:0] A,
    input wire [7:0] B,
    input wire [3:0] alu_control,
    output reg [7:0] alu_result,
    output wire zero
);

always @(*) begin
    case (alu_control)
        4'b0000: alu_result = A + B;
        4'b0001: alu_result = A - B;
        4'b0010: alu_result = A * B;
        4'b0011: alu_result = A & B;
        4'b0100: alu_result = A | B;
        4'b0101: alu_result = A ^ B;
        default: alu_result = 8'h00;
    endcase
end

assign zero = (alu_result == 8'h00);

endmodule