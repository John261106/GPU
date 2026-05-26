`timescale 1ns/1ps

module tb_gpu_top;

    reg clk;
    reg rst;

    reg start;
    reg [7:0] global_thread_count;

    reg  [7:0] mem_rdata;
    wire [7:0] mem_addr;
    wire [7:0] mem_wdata;
    wire       mem_write;

    wire [7:0] alu_result_debug [0:1];

    wire done;

    // DUT
    gpu_top dut (
        .clk(clk),
        .rst(rst),

        .start(start),
        .global_thread_count(global_thread_count),

        .mem_rdata(mem_rdata),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_write(mem_write),

        .alu_result_debug(alu_result_debug),

        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("gpu_top.vcd");
        $dumpvars(0, dut);
    end

    // Stimulus
    initial begin

        rst = 1;
        start = 0;

        global_thread_count = 8'd128;

        // Always return decimal 10 from memory
        mem_rdata = 8'd10;

        #20;
        rst = 0;

        #10;
        start = 1;

        // #10;
        // start = 0;

        // Run simulation
        #20000;

        $finish;
    end

    // Print debug outputs
    always @(posedge clk) begin
        $display("TIME=%0t | CORE0 alu_result=%0d | CORE1 alu_result=%0d | done=%b",
                 $time,
                 alu_result_debug[0],
                 alu_result_debug[1],
                 done);
    end

endmodule