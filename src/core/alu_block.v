module alu_block (
    input  wire [7:0]  RS1_warps [0:3][0:15],   // 4 warps x 16 lanes
    input  wire [7:0]  RS2_warps [0:3][0:15],   // 4 warps x 16 lanes
    input  wire [1:0]  current_warp_id,
    input  wire [3:0]  alu_control,
    input  wire        alu_src,
    input  wire [7:0]  imm,

    output wire [7:0]  alu_result [0:15],       // 16 lane results

    // Since no branch divergence:
    // only one set of flags for entire warp
    output wire        zero,
    output wire        positive,
    output wire        negative
);

    wire [7:0] RS1 [0:15];
    wire [7:0] RS2 [0:15];
    wire [7:0] alu_B [0:15];

    wire lane_zero [0:15];

    genvar i;

    generate
        for(i = 0; i < 16; i = i + 1) begin : lane

            // Select current warp registers
            assign RS1[i] = RS1_warps[current_warp_id][i];
            assign RS2[i] = RS2_warps[current_warp_id][i];

            // ALU source mux
            assign alu_B[i] = (alu_src) ? imm : RS2[i];

            // Per-lane ALU
            alu alu_inst (
                .A           (RS1[i]),
                .B           (alu_B[i]),
                .alu_control (alu_control),
                .alu_result  (alu_result[i]),
                .zero        (lane_zero[i])
            );

        end
    endgenerate

    // Since all lanes execute same instruction
    // and no branch divergence is assumed,
    // use lane 0 flags for branch decisions

    assign zero     = lane_zero[0];

    // Signed comparison flags from lane 0 result
    assign negative = alu_result[0][7];

    assign positive = (~alu_result[0][7]) && (alu_result[0] != 8'b0);

endmodule