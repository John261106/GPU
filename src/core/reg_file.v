module reg_file (
    input wire clk,
    input wire reset,
    input wire [3:0] A1,
    input wire [3:0] A2,
    input wire [3:0] A3,
    input wire [7:0] WD,
    input wire [15:0] block_idx,
    input wire [15:0] block_dim,
    input wire [15:0] thread_idx,

    output reg [7:0] RS1,
    output reg [7:0] RS2,

    input wire we
);

    reg [15:0] REGISTER [0:15];
    integer i;


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 13; i = i + 1) begin
                REGISTER[i] <= 16'h0000;
            end

            REGISTER[13] <= block_dim;
            REGISTER[14] <= block_idx;
            REGISTER[15] <= thread_idx;
        end
        else if (we && (A3 < 13)) begin
            REGISTER[A3] <= WD;
        end
    end

    // read
    always @(*) begin
        RS1 = REGISTER[A1];
        RS2 = REGISTER[A2];
    end

endmodule