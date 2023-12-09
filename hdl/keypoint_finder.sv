`timescale 1ns / 1ps
`default_nettype none

// keypoint BRAM is assumed to be x,y in each row
// so 2 * $clog2(DIMENSION) WIDTH

module keypoint_finder #(
  parameter DIMENSION, 
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter DOG_IMAGES_PER_OCTAVE = 2// the check extrema module currently assumes this is 2 always 
  ) (
  input wire clk,
  input wire rst_in,//sys_rst
  // input wire bram_ready,
  // input wire [7:0] sharper_pix,
  // input wire [7:0] fuzzier_pix,
  // output logic busy,
  // output logic [11:0] address,
  // output logic signed [8:0] data_out,
  // output logic wea,
  // output logic [1:0] state_num

  // this writes the {x,y, octave, dog_image} values for each keypoint
  // currently the width for keypoint data should be 15 (6+6+2+1)
  output logic [($clog2(NUMBER_KEYPOINTS)) - 1:0] keypoint_address,
  output logic [((2*$clog2(DIMENSION)) + $clog2(NUMBER_OCTAVES) + $clog2(DOG_IMAGES_PER_OCTAVE))- 1:0] keypoint_data,
  output logic write_keypoint_enable,

  );





endmodule


`default_nettype wire