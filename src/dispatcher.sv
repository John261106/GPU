module dispatcher #(parameter NUM_CORES = 2, NUM_WARPS = 4, NUM_THREADS = 16)(
    input clk, rst,
    input start,                    //From External-CPU

    input [7:0]global_thread_count, //From DCR(Device-Control Register)

    //Warp-States
    input           warp_done        [0:NUM_CORES-1][0:NUM_WARPS-1],
    output reg      warp_start       [0:NUM_CORES-1][0:NUM_WARPS-1],
    output reg      warp_reset       [0:NUM_CORES-1][0:NUM_WARPS-1],
    output reg [7:0]warp_id          [0:NUM_CORES-1][0:NUM_WARPS-1],
    output reg [3:0]warp_thread_count[0:NUM_CORES-1][0:NUM_WARPS-1],

    output reg done //Kernel-Done

);

    wire [4:0]total_warps;
    assign total_warps = (global_thread_count + NUM_THREADS - 1) / NUM_THREADS;

    reg [4:0]warps_dispatched;
    reg [4:0]warps_done;
    reg start_execution;

    always @(posedge clk) begin
        if(rst) begin
            done <= 0;
            warps_dispatched <= 0;
            warps_done <= 0;
            start_execution <= 0;

            for(integer i = 0; i < NUM_CORES; i = i + 1) begin
                for(integer j = 0; j < NUM_WARPS; j = j + 1) begin
                    warp_start[i][j]        <= 0;
                    warp_reset[i][j]        <= 1;
                    warp_id[i][j]           <= 0;
                    warp_thread_count[i][j] <= 0;
                end
            end
        end
        else if (start) begin
            if(!start_execution) begin
                start_execution <= 1;
                for(integer i = 0; i < NUM_CORES; i = i + 1) begin
                    for(integer j = 0; j < NUM_WARPS; j = j + 1) begin
                        warp_reset[i][j] <= 1;
                    end
                end
            end

            if (warps_done == total_warps)
                done <= 1;
            
            for(integer i = 0; i < NUM_CORES; i = i + 1) begin
                for(integer j = 0; j < NUM_WARPS; j = j + 1) begin
                    if(warp_reset[i][j]) begin
                        warp_reset[i][j] <= 0;
                        
                        if(warps_dispatched < total_warps) begin
                            warp_start[i][j]  <= 1;
                            warp_id[i][j]     <= warps_dispatched;
                            warp_thread_count[i][j] <= (warps_dispatched == total_warps - 1)
                                                ? global_thread_count - (warps_dispatched * NUM_THREADS);
                                                : NUM_THREADS;

                            warps_dispatched  <= warps_dispatched + 1;
                        end
                    end

                    if(warp_start[i][j] && warp_done[i][j]) begin
                        warp_reset[i][j] <= 1;
                        warp_start[i][j] <= 0;
                        warps_done        = warps_done + 1;
                    end
                end
            end

        end
    end

endmodule