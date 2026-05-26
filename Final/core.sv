module core #(parameter NUM_WARPS = 4, NUM_THREADS = 16)(
    input  wire clk,
    input  wire reset,

    // from memory scheduler
    input  wire        mem_done,
    input  wire [1:0]  warp_id_from_ms,
    input  wire [3:0]  lw_dest_in,
    input  wire [7:0]  lw_data_in  [0:NUM_THREADS-1],
    input  wire        lw_ready,
    input  wire [1:0]  lw_warp_id,

    // to memory scheduler
    output wire        mem_req,
    output wire        mem_write,
    output wire [1:0]  warp_id_to_ms,
    output wire [7:0]  alu_result  [0:NUM_THREADS-1],   // addresses for lw/sw
    output wire [7:0]  rs2_out     [0:NUM_THREADS-1],   // store data for sw
    output wire [3:0]  lw_dest_out,          // Destination reg address

    //Dispatcher Interface
    input wire       warp_start        [0:NUM_WARPS-1],
    input wire       warp_reset        [0:NUM_WARPS-1],
    input wire [7:0] warp_id           [0:NUM_WARPS-1],
    input wire [3:0] warp_thread_count [0:NUM_WARPS-1],

    output wire warp_done[0:NUM_WARPS-1]

);

    //Latching Dispatcher Inputs
    reg       warp_active             [0:NUM_WARPS-1];
    reg [7:0] warp_global_id          [0:NUM_WARPS-1];
    reg [3:0] warp_thread_count_local [0:NUM_WARPS-1];

    integer i;
    
    always @(posedge clk) begin
        if(reset) begin
            for(i = 0; i < NUM_WARPS; i = i + 1) begin
                warp_active[i]       <= 0;
                warp_global_id[i]    <= 0;
                warp_thread_count_local[i] <= 0;
            end
        end
        
        else begin
            for(i = 0; i < NUM_WARPS; i = i + 1) begin
                if(warp_reset[i] == 1)
                    warp_active[i] <= 0;
                else if(halt && (current_warp_id == i)) begin
                    warp_active[i] <= 0;
                end
                else if(warp_start[i] == 1) begin
                    warp_active[i]             <= 1;
                    warp_global_id[i]          <= warp_id[i];
                    warp_thread_count_local[i] <= warp_thread_count[i];
                end
            end
        end
    end

    // -------------------------
    // warp scheduler
    // -------------------------
    wire [7:0] present_warp_pc;
    wire [1 :0] current_warp_id;
    wire        halt;

    warp_scheduler #(.NUM_WARPS(4)) ws_inst (
        .clk             (clk),
        .rst             (reset),
        .mem_req         (mem_req),
        .mem_done        (mem_done),
        .halt            (halt),
        .warp_id_from_ms (warp_id_from_ms),
        .warp_active     (warp_active),
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

    wire [7:0] RS1_warps0 [0:15];
    wire [7:0] RS2_warps0 [0:15];
    genvar m;
    generate
        for(m=0; m<16; m=m+1) begin
            assign RS1_warps[0][m] = RS1_warps0[m];
            assign RS2_warps[0][m] = RS2_warps0[m];
        end
    endgenerate

    warp #(.WARP_ID(0)) warp0 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .lw_ready       (lw_ready),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps0),
        .RS2            (RS2_warps0)
    );

    wire [7:0] RS1_warps1 [0:15];
    wire [7:0] RS2_warps1 [0:15];
    
    generate
        for(m=0; m<16; m=m+1) begin
            assign RS1_warps[1][m] = RS1_warps1[m];
            assign RS2_warps[1][m] = RS2_warps1[m];
        end
    endgenerate

    warp #(.WARP_ID(1)) warp1 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .lw_ready       (lw_ready),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps1),
        .RS2            (RS2_warps1)
    );

    wire [7:0] RS1_warps2 [0:15];
    wire [7:0] RS2_warps2 [0:15];
    
    generate
        for(m=0; m<16; m=m+1) begin
            assign RS1_warps[2][m] = RS1_warps2[m];
            assign RS2_warps[2][m] = RS2_warps2[m];
        end
    endgenerate

    warp #(.WARP_ID(2)) warp2 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .lw_ready       (lw_ready),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps2),
        .RS2            (RS2_warps2)
    );

    wire [7:0] RS1_warps3 [0:15];
    wire [7:0] RS2_warps3 [0:15];
    
    generate
        for(m=0; m<16; m=m+1) begin
            assign RS1_warps[3][m] = RS1_warps3[m];
            assign RS2_warps[3][m] = RS2_warps3[m];
        end
    endgenerate

    warp #(.WARP_ID(3)) warp3 (
        .clk            (clk),
        .reset          (reset),
        .A1             (A1),
        .A2             (A2),
        .A3             (A3),
        .reg_we         (reg_we),
        .current_warp_id(current_warp_id),
        .alu_result     (alu_result),
        .lw_ready       (lw_ready),
        .lw_warp_id     (warp_id_from_ms),
        .lw_dest_in     (lw_dest_in),
        .lw_data_in     (lw_data_in),
        .RS1            (RS1_warps3),
        .RS2            (RS2_warps3)
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

    assign lw_dest_out = A3;

    // ------------------------------------
    // Warp Done Logic
    // ------------------------------------

    reg warp_done_reg [0:NUM_WARPS-1];

    integer j;

    always @(posedge clk) begin
        if(reset) begin
            for(j = 0; j < NUM_WARPS; j = j + 1)
                warp_done_reg[j] <= 0;
        end
        else begin
            for(j = 0; j < NUM_WARPS; j = j + 1) begin

                // Clear done when dispatcher resets warp
                if(warp_reset[j])
                    warp_done_reg[j] <= 0;

                // Set done when HALT instruction executes
                else if(halt && (current_warp_id == j))
                    warp_done_reg[j] <= 1;
            end
        end
    end

    generate
        genvar d;
        for(d = 0; d < NUM_WARPS; d = d + 1) begin
            assign warp_done[d] = warp_done_reg[d];
        end
    endgenerate

endmodule