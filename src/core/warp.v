module warp #(
    parameter WARP_ID = 0
) (
    input wire clk,
    input wire reset,

    // decoder signals
    input wire [3:0]  A1,
    input wire [3:0]  A2,
    input wire [3:0]  A3,
    input wire  reg_we,
    input wire [1:0]  current_warp_id,

    // alu results (16 lanes)
    input wire [7:0]  alu_result [0:15],

    // lw writeback
    input wire  mem_done,
    input wire [1:0]  lw_warp_id,
    input wire [3:0]  lw_reg,
    input wire [7:0]  lw_data   [0:15],

    // outputs to alu block
    output wire [7:0] RS1 [0:15],
    output wire [7:0] RS2 [0:15]
);

    // write enable conditions
    wire normal_we  = reg_we  && (current_warp_id == WARP_ID);
    wire lw_we  = mem_done && (lw_warp_id     == WARP_ID);

    genvar i;
    generate
        for(i = 0; i < 16; i = i + 1) begin : lane

            reg_file reg_inst (
                .clk (clk),
                .reset (reset),

                // read addresses
                .A1 (A1),
                .A2 (A2),

                // write address: lw_reg if writeback, else A3
                .A3  (lw_we ? lw_reg : A3),

                // write data: lw_data if writeback, else alu_result
                .WD (lw_we ? lw_data[i] : alu_result[i]),

                // write enable: either normal or lw writeback
                .we (normal_we || lw_we),

                // special registers
                .block_idx (16'd(WARP_ID)),
                .block_dim (16'd16),
                .thread_idx(16'd(i)),

                // outputs
                .RS1       (RS1[i]),
                .RS2       (RS2[i])
            );
        end
    endgenerate

endmodule