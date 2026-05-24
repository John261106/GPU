module alu_block (
    input  wire [7:0]  RS1_warps [0:3][0:15],   // 4 warps x 16 lanes
    input  wire [7:0]  RS2_warps [0:3][0:15],   // 4 warps x 16 lanes
    input  wire [1:0]  current_warp_id,
    input  wire [3:0]  alu_control,
    input  wire        alu_src,
    input  wire [7:0]  imm,
    output wire [7:0]  alu_result [0:15],        // 16 results
    output wire        zero       [0:15]         // 16 zero flags
);

    
    wire [7:0] RS1 [0:15];
    wire [7:0] RS2 [0:15];
    wire [7:0] alu_B [0:15];

    genvar i;
    generate
        for(i = 0; i < 16; i = i + 1) begin : lane
            // select current warp's register data
            assign RS1[i] = RS1_warps[current_warp_id][i];
            assign RS2[i] = RS2_warps[current_warp_id][i];

            
            assign alu_B[i] = alu_src ? imm : RS2[i];

            
            alu alu_inst (
                .A          (RS1[i]),
                .B          (alu_B[i]),
                .alu_control(alu_control),
                .alu_result (alu_result[i]),
                .zero       (zero[i])
            );
        end
    endgenerate

endmodule