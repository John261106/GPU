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
    input wire        lw_ready,
    input wire [1:0]  lw_warp_id,
    input wire [3:0]  lw_dest_in,
    input wire [7:0]  lw_data_in   [0:15],

    // outputs to alu block
    output wire [7:0] RS1 [0:15],
    output wire [7:0] RS2 [0:15]
);

    // write enable conditions
    wire normal_we  = reg_we  && (current_warp_id == WARP_ID);
    wire lw_we  = lw_ready && (lw_warp_id     == WARP_ID);

    genvar i;
    generate
        for(i = 0; i < 16; i = i + 1) begin : lane

            reg_file reg_inst (
		    .clk (clk),
		    .reset (reset),

		    // read addresses
		    .A1 (A1),
		    .A2 (A2),

		    // write address
		    .A3 (lw_we ? lw_dest_in : A3),

		    // write data
		    .WD (lw_we ? lw_data_in[i] : alu_result[i]),

		    // write enable
		    .we (normal_we || lw_we),

		    // special registers
		    .block_idx (WARP_ID[1:0]),
		    .block_dim (16'd16),
		    .thread_idx (i[4:0]),

		    // outputs
		    .RS1 (RS1[i]),
		    .RS2 (RS2[i])
		);
        end
    endgenerate

endmodule
