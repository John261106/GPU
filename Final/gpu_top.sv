module gpu_top #(parameter NUM_CORES = 2, NUM_WARPS = 4, NUM_THREADS = 16)(
    input clk, rst,

    input       start,
    input [7:0] global_thread_count,

    input  [7:0] mem_rdata,
    output [7:0] mem_addr,
    output [7:0] mem_wdata,
    output       mem_write,

    output [7:0] alu_result_debug[0:1],

    output done
);


wire       warp_start        [0:NUM_CORES-1][0:NUM_WARPS-1];
wire       warp_reset        [0:NUM_CORES-1][0:NUM_WARPS-1];
wire [7:0] global_warp_id    [0:NUM_CORES-1][0:NUM_WARPS-1];
wire [3:0] warp_thread_count [0:NUM_CORES-1][0:NUM_WARPS-1];

wire       warp_done         [0:NUM_CORES-1][0:NUM_WARPS-1];

dispatcher #(
    .NUM_CORES(NUM_CORES),
    .NUM_WARPS(NUM_WARPS),
    .NUM_THREADS(NUM_THREADS)
) dispatcher_inst (
    .clk(clk),
    .rst(rst),
    .start(start),

    .global_thread_count(global_thread_count),

    .warp_done(warp_done),

    .warp_start(warp_start),
    .warp_reset(warp_reset),
    .warp_id(global_warp_id),
    .warp_thread_count(warp_thread_count),

    .done(done)
);

wire       mem_req         [0:NUM_CORES-1];
wire       mem_write_core  [0:NUM_CORES-1];
wire [1:0] warp_id_to_ms   [0:NUM_CORES-1];
wire [7:0] alu_result      [0:NUM_CORES-1][0:NUM_THREADS-1];
wire [7:0] rs2_out         [0:NUM_CORES-1][0:NUM_THREADS-1];
wire [3:0] lw_dest_out     [0:NUM_CORES-1];
wire       mem_done        [0:NUM_CORES-1];
wire [1:0] warp_id_from_ms [0:NUM_CORES-1];
wire [3:0] lw_dest_in      [0:NUM_CORES-1];
wire [7:0] lw_data_in      [0:NUM_CORES-1][0:NUM_THREADS-1];
wire       lw_ready        [0:NUM_CORES-1];
wire [1:0] lw_warp_id      [0:NUM_CORES-1];

// Flat per-core wires for thread-indexed ports (iverilog can't slice 2D arrays at port connections)
wire [7:0] alu_result0 [0:NUM_THREADS-1];
wire [7:0] rs2_out0    [0:NUM_THREADS-1];
wire [7:0] lw_data_in0 [0:NUM_THREADS-1];
wire [7:0] alu_result1 [0:NUM_THREADS-1];
wire [7:0] rs2_out1    [0:NUM_THREADS-1];
wire [7:0] lw_data_in1 [0:NUM_THREADS-1];

// Flat per-core wires for warp-indexed ports
wire       warp_start0        [0:NUM_WARPS-1];
wire       warp_reset0        [0:NUM_WARPS-1];
wire [7:0] global_warp_id0    [0:NUM_WARPS-1];
wire [3:0] warp_thread_count0 [0:NUM_WARPS-1];
wire       warp_done0         [0:NUM_WARPS-1];

wire       warp_start1        [0:NUM_WARPS-1];
wire       warp_reset1        [0:NUM_WARPS-1];
wire [7:0] global_warp_id1    [0:NUM_WARPS-1];
wire [3:0] warp_thread_count1 [0:NUM_WARPS-1];
wire       warp_done1         [0:NUM_WARPS-1];

genvar m;
generate
    for (m = 0; m < NUM_THREADS; m = m+1) begin : thread_wire_connect
        assign alu_result[0][m] = alu_result0[m];
        assign rs2_out[0][m]    = rs2_out0[m];
        assign lw_data_in0[m]   = lw_data_in[0][m];
        assign alu_result[1][m] = alu_result1[m];
        assign rs2_out[1][m]    = rs2_out1[m];
        assign lw_data_in1[m]   = lw_data_in[1][m];
        assign lw_data_in0[m] = lw_data_out0[m]; 
        assign lw_data_in1[m] = lw_data_out1[m];
    end
endgenerate

genvar w;
generate
    for (w = 0; w < NUM_WARPS; w = w+1) begin : warp_wire_connect
        // core0
        assign warp_start0[w]        = warp_start[0][w];
        assign warp_reset0[w]        = warp_reset[0][w];
        assign global_warp_id0[w]    = global_warp_id[0][w];
        assign warp_thread_count0[w] = warp_thread_count[0][w];
        assign warp_done[0][w]       = warp_done0[w];
        // core1
        assign warp_start1[w]        = warp_start[1][w];
        assign warp_reset1[w]        = warp_reset[1][w];
        assign global_warp_id1[w]    = global_warp_id[1][w];
        assign warp_thread_count1[w] = warp_thread_count[1][w];
        assign warp_done[1][w]       = warp_done1[w];
    end
endgenerate

core #(
    .NUM_WARPS(NUM_WARPS),
    .NUM_THREADS(NUM_THREADS)
) core0 (
    .clk(clk),
    .reset(rst),

    // from mem scheduler
    .mem_done(mem_done[0]),
    .warp_id_from_ms(warp_id_from_ms[0]),
    .lw_dest_in(lw_dest_in[0]),
    .lw_data_in({lw_data_out[0][0], lw_data_out[1][0], lw_data_out[2][0], lw_data_out[3][0], lw_data_out[4][0], lw_data_out[5][0], lw_data_out[6][0], lw_data_out[7][0], lw_data_out[8][0], lw_data_out[9][0], lw_data_out[10][0], lw_data_out[11][0], lw_data_out[12][0], lw_data_out[13][0], lw_data_out[14][0], lw_data_out[15][0]}),
    .lw_ready(lw_ready[0]),
    .lw_warp_id(lw_warp_id[0]),

    // to mem scheduler
    .mem_req(mem_req[0]),
    .mem_write(mem_write_core[0]),
    .warp_id_to_ms(warp_id_to_ms[0]),
    .alu_result(alu_result0),
    .rs2_out(rs2_out0),
    .lw_dest_out(lw_dest_out[0]),

    // dispatcher interface
    .warp_start(warp_start0),
    .warp_reset(warp_reset0),
    .warp_id(global_warp_id0),
    .warp_thread_count(warp_thread_count0),
    .warp_done(warp_done0)
);

core #(
    .NUM_WARPS(NUM_WARPS),
    .NUM_THREADS(NUM_THREADS)
) core1 (
    .clk(clk),
    .reset(rst),

    // from mem scheduler
    .mem_done(mem_done[1]),
    .warp_id_from_ms(warp_id_from_ms[1]),
    .lw_dest_in(lw_dest_in[1]),
    .lw_data_in({lw_data_out[0][1], lw_data_out[1][1], lw_data_out[2][1], lw_data_out[3][1], lw_data_out[4][1], lw_data_out[5][1], lw_data_out[6][1], lw_data_out[7][1], lw_data_out[8][1], lw_data_out[9][1], lw_data_out[10][1], lw_data_out[11][1], lw_data_out[12][1], lw_data_out[13][1], lw_data_out[14][1], lw_data_out[15][1]}),
    .lw_ready(lw_ready[1]),
    .lw_warp_id(lw_warp_id[1]),

    // to mem scheduler
    .mem_req(mem_req[1]),
    .mem_write(mem_write_core[1]),
    .warp_id_to_ms(warp_id_to_ms[1]),
    .alu_result(alu_result1),
    .rs2_out(rs2_out1),
    .lw_dest_out(lw_dest_out[1]),

    // dispatcher interface
    .warp_start(warp_start1),
    .warp_reset(warp_reset1),
    .warp_id(global_warp_id1),
    .warp_thread_count(warp_thread_count1),
    .warp_done(warp_done1)
);

wire [7:0] lw_data_out0 [0:NUM_THREADS-1]; 
wire [7:0] lw_data_out1 [0:NUM_THREADS-1];


wire [7:0] lw_data_out [0:15][0:1];
mem_scheduler #(
    .NUM_CORES(NUM_CORES),
    .NUM_WARPS(NUM_WARPS),
    .NUM_THREADS(NUM_THREADS)
) ms_inst (

    .clk(clk),
    .rst(rst),
    
    // from cores
    .mem_write_in(mem_write_core),
    .mem_req(mem_req),
    .active_mask('{default: {NUM_THREADS{1'b1}}}),

    .warp_id_from_ws(warp_id_to_ms),

    .addr_in(alu_result),
    .sw_data_in(rs2_out),

    .lw_dest_in(lw_dest_out),

    // back to cores
    .mem_done(mem_done),
    .warp_id_to_ws(warp_id_from_ms),

    .lw_dest_out(lw_dest_in),

    .lw_data_out(lw_data_out),

    .lw_warp_id(lw_warp_id),
    .lw_ready(lw_ready),

    // external memory
    .lw_data_in(mem_rdata),
    .addr_out(mem_addr),
    .sw_data_out(mem_wdata),
    .mem_write(mem_write)
);

    assign alu_result_debug[0] = alu_result[0][0];
    assign alu_result_debug[1] = alu_result[1][0];

endmodule