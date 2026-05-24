module core (
    input  wire clk,
    input  wire reset,

    // from memory scheduler
    input  wire        mem_done,
    input  wire [1:0]  warp_id_from_ms,
    input  wire [3:0]  lw_dest_in,
    input  wire [7:0]  lw_data_in  [0:15],

    // to memory scheduler
    output wire        mem_req,
    output wire        mem_write,
    output wire [1:0]  warp_id_to_ms,
    output wire [7:0]  alu_result  [0:15],   // addresses for lw/sw
    output wire [7:0]  rs2_out     [0:15]    // store data for sw
);

    // -------------------------
    // warp scheduler
    // -------------------------
    wire [15:0] present_warp_pc;
    wire [1:0]  current_warp_id;
    wire        halt;

    warp_scheduler #(.NUM_WARPS(4)) ws_inst (
        .clk             (clk),
        .rst             (reset),
        .mem_req         (mem_req),
        .mem_done        (mem_done),
        .halt            (halt),
        .warp_id_from_ms (warp_id_from_ms),
        .warp_id_to_ms   (warp_id_to_ms),
        .present_warp_pc (present_warp_pc),
        .present_warp_mask(),
        .current_warp_id (current_warp_id)
    );

    // -------------------------
    // instruction memory
    // -------------------------
    wire [15:0] instr;

    instr_mem instr_mem_inst (
        .pc   (present_warp_pc),
        .instr(instr)
    );

    // -------------------------
    // decoder
    // -------------------------
    wire [3:0] A1, A2, A3;
    wire [3:0] imm_raw;
    wire [3:0] alu_control;
    wire       alu_src;
    wire       reg_we;

    decoder dec_inst (
        .instr      (instr),
        .mem_req    (mem_req),
        .halt       (halt),
        .opcode     (),              // unused at top level
        .alu_control(alu_control),
        .mem_write  (mem_write),
        .reg_we     (reg_we),
        .alu_src    (alu_src),
        .A1         (A1),
        .A2         (A2),
        .A3         (A3),
        .imm        (imm_raw)
    );

    // -------------------------
    // immediate generator
    // -------------------------
    wire [7:0] imm_out;

    imm_gen imm_gen_inst (
        .imm    (imm_raw),
        .imm_out(imm_out)
    );

    // -------------------------
    // 4 warp register file banks
    // -------------------------
    wire [7:0] RS1_warps [0:3][0:15];
    wire [7:0] RS2_warps [0:3][0:15];

    warp #(.WARP_ID(0)) warp0 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .mem_done       (mem_done),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps[0]),
        .RS2            (RS2_warps[0])
    );

    warp #(.WARP_ID(1)) warp1 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .mem_done       (mem_done),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps[1]),
        .RS2            (RS2_warps[1])
    );

    warp #(.WARP_ID(2)) warp2 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .mem_done       (mem_done),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps[2]),
        .RS2            (RS2_warps[2])
    );

    warp #(.WARP_ID(3)) warp3 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .mem_done       (mem_done),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps[3]),
        .RS2            (RS2_warps[3])
    );

    // -------------------------
    // RS2 mux — select current warp's RS2 for SW store data
    // -------------------------
    genvar k;
    generate
        for(k = 0; k < 16; k = k + 1) begin : rs2_mux
            assign rs2_out[k] = RS2_warps[current_warp_id][k];
        end
    endgenerate

    // -------------------------
    // ALU block
    // -------------------------
    wire zero [0:15];

    alu_block alu_block_inst (
        .RS1_warps      (RS1_warps),
        .RS2_warps      (RS2_warps),
        .current_warp_id(current_warp_id),
        .alu_control    (alu_control),
        .alu_src        (alu_src),
        .imm            (imm_out),
        .alu_result     (alu_result),
        .zero           (zero)
    );

endmodule