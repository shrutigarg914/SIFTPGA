`timescale 1ns / 1ps
`default_nettype none


// dummy histogram header
module histogram #(
  parameter DIMENSION = 64,
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter BIT_DEPTH = 8,
  parameter PATCH_SIZE = 4
  ) (
    input wire clk,
    input wire rst_in

    // the handle to output the histogram to
    output logic wea,
    output logic [$clog2(PATCH_SIZE/2 * PATCH_SIZE/2)*8-1:0] histogram_out,  // 4 by 4 --> 2 by 2 subpatches 
                            // --> 4 total orientations --> max 2 bits each for each of 8 possible values
    
    // coordinates of the top left pixel of the patch
    input wire [$clog2(DIMENSION)-1:0] x,
    input wire [$clog2(DIMENSION)-1:0] y,

    // handles to read from the gradient pyramid
    input wire signed [BIT_DEPTH-1:0] x_grad,
    input wire signed [BIT_DEPTH-1:0] y_grad,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] x_grad_address,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] y_grad_address,

    // start and done signals
    input wire start,
    output logic histogram_done
  );
endmodule // histogram


`default_nettype wire