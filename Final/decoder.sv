module decoder (
    input  wire [15:0] instr,      
    output reg  mem_req,
    output wire halt,
    output wire [3:0]  opcode,
    output reg  [3:0]  alu_control,
    output wire mem_write,
    output reg  reg_we,
    output reg  alu_src,
    output wire [3:0]  A1,
    output wire [3:0]  A2,
    output wire [3:0]  A3,
    output wire [3:0]  imm
);

    
    assign opcode    = instr[15:12];
    assign A3  = instr[11:8];
    assign A1  = instr[7:4];
    assign A2  = instr[3:0];
    assign imm = instr[3:0];

    
    assign halt = (opcode == 4'b1000);
    assign mem_write = (opcode == 4'b0111);

    always @(*) begin
        mem_req = 1'b0;
        case(opcode)
            4'b0000: begin // ADD
                alu_control = 4'b0000;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0001: begin // SUB
                alu_control = 4'b0001;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0010: begin // MUL
                alu_control = 4'b0010;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0011: begin // AND
                alu_control = 4'b0011;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0100: begin // OR
                alu_control = 4'b0100;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0101: begin // XOR
                alu_control = 4'b0101;
                reg_we      = 1'b1;
                alu_src     = 1'b0;
            end
            4'b0110: begin // LW
                alu_control = 4'b0000;
                reg_we      = 1'b0;
                alu_src     = 1'b1;
                mem_req     = 1'b1;
            end
            4'b0111: begin // SW
                alu_control = 4'b0000;
                reg_we      = 1'b0;
                alu_src     = 1'b1;
                mem_req     = 1'b1;
            end
            4'b1000: begin // HALT
                alu_control = 4'b0000;
                reg_we      = 1'b0;
                alu_src     = 1'b0;
            end
            default: begin
                alu_control = 4'b0000;
                reg_we      = 1'b0;
                alu_src     = 1'b0;
            end
        endcase
    end

endmodule