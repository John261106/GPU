module instr_mem (
    input  logic [7:0] pc,
    output logic [15:0] instr
);

reg [15:0] instr_mem [0:255];

initial begin
    // Initialize all locations to 0
    integer i;
    for(i = 0; i < 256; i = i + 1)
        instr_mem[i] = 16'h0000;

    // Example instructions
    instr_mem[0] = 16'h6200;
    instr_mem[1] = 16'h0421;
    instr_mem[2] = 16'h0541;
    instr_mem[3] = 16'h7005;
end

always @(*) begin
    instr = instr_mem[pc];
end

endmodule