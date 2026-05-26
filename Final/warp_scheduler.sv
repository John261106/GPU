module warp_scheduler #(parameter NUM_WARPS = 4) (
    input clk, rst,
    input mem_req,
    input mem_done,
    input halt,
    input [1:0]warp_id_from_ms,
    input warp_active[0:NUM_WARPS-1],

    output [1:0]warp_id_to_ms,
    output [7:0]present_warp_pc,
    output [15:0]present_warp_mask,
    output [1:0]current_warp_id
);

reg [1:0]current_warp;

// Warp-Table
reg [7:0]warp_pc[0:NUM_WARPS-1];
reg [15:0]warp_mask[0:NUM_WARPS-1];
reg warp_stalled[0:NUM_WARPS-1];
reg warp_finished[0:NUM_WARPS-1];

parameter IDLE      = 2'b00, 
          SEARCHING = 2'b01,
          HALTED    = 2'b10;

reg [1:0]present_state;

reg found;

always @(posedge clk) begin
    if(rst) begin
        for(integer i=0; i < NUM_WARPS; i=i+1) begin
            warp_mask[i]     <= 16'hFFFF;
            warp_stalled[i]  <= 0;
            warp_finished[i] <= 0;
        end

        current_warp  <= 0;
        present_state <= IDLE;

        warp_pc[0] <= 8'h00;
        warp_pc[1] <= 8'h00;
        warp_pc[2] <= 8'h00;
        warp_pc[3] <= 8'h00;
    end
    else begin
        case(present_state)
            IDLE: begin
                if(mem_req) begin
                    warp_stalled[current_warp]    <= 1;
                    present_state                 <= SEARCHING;
                end
                if(halt) begin
                    warp_finished[current_warp]   <= 1;
                    present_state                 <= HALTED;
                end
                if(mem_done) begin
                    warp_stalled[warp_id_from_ms] <= 0;
                    warp_pc[warp_id_from_ms] <= warp_pc[warp_id_from_ms] + 1;
                end
                if((mem_req == 0) && (halt == 0) && (warp_active[current_warp])) begin
                    warp_pc[current_warp] <= warp_pc[current_warp] + 1;
                end
            end
            SEARCHING: begin
                if(mem_done) begin
                    warp_stalled[warp_id_from_ms] <= 0;
                    warp_pc[warp_id_from_ms] <= warp_pc[warp_id_from_ms] + 1;
                end
                found = 0;
                for(integer i=0; i < NUM_WARPS ; i=i+1) begin
                    integer id;
                    id = (current_warp + i) % NUM_WARPS;
                    if(warp_stalled[id]==0 && warp_finished[id]==0 && found==0 && warp_active[id]) begin
                        current_warp  <= id;
                        present_state <= IDLE;
                        found = 1;
                        // break;
                    end
                end
            end
            HALTED: begin
                if(mem_done) begin
                    warp_stalled[warp_id_from_ms] <= 0;
                    warp_pc[warp_id_from_ms] <= warp_pc[warp_id_from_ms] + 1;
                end
                found = 0;
                for(integer i=0; i < NUM_WARPS ; i=i+1) begin
                    integer id;
                    id = (current_warp + i) % NUM_WARPS;
                    if(warp_stalled[id]==0 && warp_finished[id]==0 && found==0 && warp_active[id]) begin
                        current_warp  <= id;
                        present_state <= IDLE;
                        found = 1;
                        // break;
                    end
                end
            end
            default: present_state <= IDLE;
        endcase
    end
end

assign warp_id_to_ms     = current_warp;
assign current_warp_id   = current_warp;
assign present_warp_pc   = warp_pc[current_warp];
assign present_warp_mask = warp_mask[current_warp];

endmodule
