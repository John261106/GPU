module imm_gen (
    input  wire [3:0] imm,      
    output wire [7:0] imm_out
);

    assign imm_out = {4'b0 , imm};   

endmodule