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


    genvar i;
    generate
    for(i = 0; i < 16; i = i + 1) begin : lane

        alu alu_inst (
            .A          (RS1_warps[current_warp_id][i]),
            .B          (alu_src ? imm : RS2_warps[current_warp_id][i]),
            .alu_control(alu_control),
            .alu_result (alu_result[i]),
            .zero       (zero[i])
        );

    end
    endgenerate


endmodule