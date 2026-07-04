// //Device Control Register(Stores the Kernel Metadata - In this case only the No. of Threads to be executed in this kernel)

// module dcr(
//     input clk, rst,

//     input       dcr_wr_ena,
//     input  [7:0]device_control_data,
//     output [7:0]thread_count
// );

//     reg [7:0]device_control_register;
    
//     always @(posedge clk) begin
//         if(reset)
//             device_control_register <= 0;
//         else if(dcr_wr_ena) begin
//             device_control_register <= device_control_data;
//         end 
//     end

//     assign thread_count = device_control_register;
// endmodule
