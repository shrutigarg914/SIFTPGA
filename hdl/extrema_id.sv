`timescale 1ns / 1ps
`default_nettype none


module extrema #(parameter DIMENSION) (
  input wire clk,
  input wire rst_in,
  input wire bram_ready,
  input wire [7:0] sharper_pix,
  input wire [7:0] fuzzier_pix,
  output logic busy,
  output logic [11:0] address,
  output logic signed [8:0] data_out,
  output logic wea,
  output logic [1:0] state_num
  );

endmodule // extrema

`default_nettype wire
