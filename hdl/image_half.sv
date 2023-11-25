`timescale 1ns / 1ps
`default_nettype none

module image_half #( 
                    parameter BIT_DEPTH = 8,
                    parameter NEW_HEIGHT = 64
                    ) (
                    input wire clk_in,
                    input wire rst_in,

                    input logic[BIT_DEPTH-1:0] data_in,
                    input logic[7:0] data_x_in,
                    input logic[7:0] data_y_in,
                    input logic data_valid_in,

                    output logic[BIT_DEPTH-1:0] data_out,
                    output logic[7:0] data_addr_out,
                    output logic data_valid_out,

                    output logic error_out,
                    output logic busy_out);

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        data_out <= 0;
        data_addr_out <= 0;
        data_valid_out <= 0;
    end else begin
        if (data_valid_in) begin
            if (data_x_in[0] == 0 && data_y_in[0] == 0) begin
                data_out <= data_in;
                data_addr_out <= (data_y_in >> 1) * NEW_HEIGHT + (data_x_in >> 1);
                data_valid_out <= 1;
            end
            else begin
                data_valid_out <= 0;
            end
        end
        else begin
            data_valid_out <= 0;
        end
    end
  end

endmodule
