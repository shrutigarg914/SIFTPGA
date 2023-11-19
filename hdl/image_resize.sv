module image_resize #(parameter WIDTH = 8) (
                    input wire clk_in,
                    input wire rst_in,

                    input wire[WIDTH*3-1:0] r0_data_in,
                    input wire[WIDTH*3-1:0] r1_data_in,
                    input wire[WIDTH*3-1:0] r2_data_in,
                    input wire data_valid_in,

                    output logic[WIDTH-1:0] data_out,
                    output logic data_valid_out,

                    output logic error_out,
                    output logic busy_out);

endmodule
