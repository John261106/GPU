module mem_scheduler #(parameter NUM_CORES = 2, NUM_WARPS = 4, NUM_THREADS = 16, DATA_WIDTH = 8, ADDR_WIDTH = 8, QUEUE_LEN = 8) (
    input  clk, rst,
    input                   mem_write_in [0:NUM_CORES-1],
    input  [NUM_THREADS-1:0]active_mask  [0:NUM_CORES-1],
    input  [ADDR_WIDTH-1:0] addr_in      [0:NUM_THREADS-1][0:NUM_CORES-1],
    input  [DATA_WIDTH-1:0] sw_data_in   [0:NUM_THREADS-1][0:NUM_CORES-1],
    
    output reg [DATA_WIDTH-1:0] lw_data_out [0:NUM_THREADS-1][0:NUM_CORES-1],
    output reg mem_write,

    //warp-scheduler interface
    input        mem_req         [0:NUM_CORES-1],
    input  [1:0] warp_id_from_ws [0:NUM_CORES-1],

    output reg       mem_done      [0:NUM_CORES-1],
    output reg [1:0] warp_id_to_ws [0:NUM_CORES-1],
    input      [3:0] lw_dest_in    [0:NUM_CORES-1],
    output reg [3:0] lw_dest_out   [0:NUM_CORES-1],

    input      [DATA_WIDTH-1:0]lw_data_in,
    output reg [ADDR_WIDTH-1:0]addr_out,
    output reg [DATA_WIDTH-1:0]sw_data_out,

    output reg [1:0] lw_warp_id [0:NUM_CORES-1],
    output reg       lw_ready   [0:NUM_CORES-1]
);

// Queue-Table
reg [ADDR_WIDTH-1:0] ADDR       [0:QUEUE_LEN-1][0:NUM_THREADS-1];
reg [DATA_WIDTH-1:0] SW_DATA    [0:QUEUE_LEN-1][0:NUM_THREADS-1];
reg [1:0]            WARP_ID    [0:QUEUE_LEN-1];
reg                  CORE_ID    [0:QUEUE_LEN-1];
reg                  REQ_DONE   [0:QUEUE_LEN-1];
reg                  Q_OCCUPIED [0:QUEUE_LEN-1];
reg                  REQ_TYPE   [0:QUEUE_LEN-1];
reg [3:0]            LW_DEST    [0:QUEUE_LEN-1];

parameter IDLE    = 3'b000, 
          WARP    = 3'b001, 
          REQ     = 3'b010, 
          WAIT    = 3'b011, 
          CAPTURE = 3'b100, 
          DONE    = 3'b101;

reg [2:0]present_state;
integer current_lane;
reg request_reg;
reg [1:0]current_warp_in_ms;
reg current_core_in_ms;
reg [2:0]queue_pointer;

reg found1, found2, found_warp, duplicate_found0, duplicate_found1;

always @(posedge clk) begin
    if(rst) begin
        present_state <= IDLE;
        sw_data_out   <= 0;
        addr_out      <= 0;
        current_lane  <= 0;
        mem_write     <= 0;
        request_reg   <= 0;
        current_warp_in_ms <= 0;
        current_core_in_ms <= 0;
        queue_pointer <= 0;

        // Reset per-core outputs
        for(integer i = 0; i < NUM_CORES; i = i + 1) begin
            lw_warp_id[i]    <= 0;
            lw_ready[i]      <= 0;
            mem_done[i]      <= 0;
            warp_id_to_ws[i] <= 0;
            lw_dest_out[i]   <= 0;
        end

        // Reset queue table
        for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
            WARP_ID[i]    <= 0;
            CORE_ID[i]    <= 0;
            REQ_DONE[i]   <= 1'b1;
            Q_OCCUPIED[i] <= 0;
            REQ_TYPE[i]   <= 0;
            LW_DEST[i]    <= 0;

            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                ADDR[i][j]    <= 0;
                SW_DATA[i][j] <= 0;
            end
        end
    end
    else begin
        case (present_state)
            IDLE: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end
                if(!mem_req[0] && !mem_req[1]) begin
                    if(!(REQ_DONE[0] && REQ_DONE[1] && REQ_DONE[2] && REQ_DONE[3] && REQ_DONE[4] && REQ_DONE[5] && REQ_DONE[6] && REQ_DONE[7])) begin //find next warp if any left 
                        present_state <= WARP;
                        current_lane  <= 0;
                    end
                end

                for(integer k = 0; k < NUM_CORES; k = k + 1) begin
                    mem_write   <= 0;
                    mem_done[k] <= 0;
                    lw_ready[k] <= 0;
                end
            end

            WARP: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end

                found_warp = 0;
                for(integer i=0; i < QUEUE_LEN; i=i+1) begin
                    if((REQ_DONE[i] == 0) && (Q_OCCUPIED[i] == 1) && (found_warp == 0)) begin
                        current_warp_in_ms <= WARP_ID[i];
                        current_core_in_ms <= CORE_ID[i];
                        queue_pointer      <= i;
                        request_reg        <= REQ_TYPE[i];
                        present_state      <= REQ;
                        found_warp          = 1;
                        // break;
                    end
                end
            end

            REQ: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end

                mem_write <= 0;

                if(request_reg) begin  //lw
                    if(current_lane < NUM_THREADS) begin
                        if(active_mask[current_core_in_ms][current_lane]) begin
                            addr_out <= ADDR[queue_pointer][current_lane];
                            present_state <= WAIT;
                        end else
                            current_lane <= current_lane + 1;
                    end
                    else if(current_lane >= NUM_THREADS) begin
                        present_state                   <= DONE;
                        REQ_DONE[queue_pointer]         <= 1;
                        lw_dest_out[current_core_in_ms] <= LW_DEST[queue_pointer];
                        lw_ready[current_core_in_ms]    <= 1;
                        lw_warp_id[current_core_in_ms]  <= current_warp_in_ms;
                    end
                end
                else begin    //sw
                    if(current_lane < NUM_THREADS) begin
                        if(active_mask[current_core_in_ms][current_lane]) begin
                            mem_write     <= 1;
                            addr_out      <= ADDR[queue_pointer][current_lane];
                            sw_data_out   <= SW_DATA[queue_pointer][current_lane];
                            present_state <= WAIT;
                        end
                        else
                            current_lane  <= current_lane + 1;
                    end
                    else if(current_lane >= NUM_THREADS) begin
                        present_state           <= DONE;
                        REQ_DONE[queue_pointer] <= 1;
                    end
                end
            end

            WAIT: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end

                present_state <= CAPTURE;                
            end

            CAPTURE: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end

                if(request_reg)
                    lw_data_out[current_lane][current_core_in_ms] <= lw_data_in;
                current_lane  <= current_lane + 1;
                present_state <= REQ;
            end

            DONE: begin
                duplicate_found0 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found0 = 1;
                    end
                end

                if(mem_req[0] && !duplicate_found0) begin
                    found1 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found1 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[0];
                            CORE_ID[i]    <= 0;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[0] == 0);
                            if(mem_write_in[0] == 0)
                                LW_DEST[i] <= lw_dest_in[0];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][0];
                                SW_DATA[i][j] <= sw_data_in[j][0];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found1 = 1;
                            // break;
                        end
                    end
                end

                duplicate_found1 = 0;
                for(integer k = 0; k < QUEUE_LEN; k = k + 1) begin
                    if(Q_OCCUPIED[k] &&
                    !REQ_DONE[k] &&
                    (CORE_ID[k] == 0) &&
                    (WARP_ID[k] == warp_id_from_ws[0])) begin
                        duplicate_found1 = 1;
                    end
                end

                if(mem_req[1] && !duplicate_found1) begin
                    found2 = 0;
                    for(integer i = 0; i < QUEUE_LEN; i = i + 1) begin
                        if(Q_OCCUPIED[i] == 0 && found2 == 0) begin
                            WARP_ID[i]    <= warp_id_from_ws[1];
                            CORE_ID[i]    <= 1;
                            Q_OCCUPIED[i] = 1;
                            REQ_DONE[i]   <= 0;
                            REQ_TYPE[i]   <= (mem_write_in[1] == 0);
                            if(mem_write_in[1] == 0)
                                LW_DEST[i] <= lw_dest_in[1];
                            for(integer j = 0; j < NUM_THREADS; j = j + 1) begin
                                ADDR[i][j]    <= addr_in[j][1];
                                SW_DATA[i][j] <= sw_data_in[j][1];
                            end
                            current_lane  <= 0;
                            present_state <= WARP;
                            found2 = 1;
                            // break;
                        end
                    end
                end

                mem_done[current_core_in_ms]        <= 1;
                current_lane                        <= 0;
                present_state                       <= IDLE;
                Q_OCCUPIED[queue_pointer]           <= 0;
                warp_id_to_ws[current_core_in_ms]   <= current_warp_in_ms;
            end

            default: present_state <= IDLE;
        endcase
    end
end

endmodule
