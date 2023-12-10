`timescale 1ns / 1ps
`default_nettype none

// keypoint BRAM is assumed to be x,y in each row
// so 2 * $clog2(DIMENSION) WIDTH

// lets first find keypoints from only one scale!
// GOAL: given the gaussian pyramid, write the keypoint BRAM

module find_keypoints #(
  parameter TOP_HEIGHT = 64, 
  parameter TOP_WIDTH = 64, 
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter DOG_IMAGES_PER_OCTAVE = 2// the check extrema module currently assumes this is 2 always 
  parameter IMG_BIT_DEPTH = 8
  ) (
  input wire clk,
  input wire rst_in,

  // handles to the keypoint BRAMs

  // FOR OCTAVE 1
  output logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] O1key_write_addr,
  output logic O1key_write_valid,
  output logic [((2*$clog2(DIMENSION)) + $clog2(NUMBER_OCTAVES) + $clog2(DOG_IMAGES_PER_OCTAVE))- 1:0] O1_keypoint_out,


  // stealing the inputs/outputs from gaussian pyramid for consistency in naming
  // we want to read from the pyramid BRAMs, so we need to output addresses and read data
  
  // Octave 1
  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L1_data,

  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L2_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L2_data,
  
  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L3_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L3_data,
  
  // // Octave 2
  // output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L1_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O2L1_data,

  // output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L2_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O2L2_data,
  
  // output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L3_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O2L3_data,
  
  // // Octave 3
  // output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L1_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O3L1_data,

  // output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L2_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O3L2_data,
  
  // output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L3_read_addr,
  // input wire [IMG_BIT_DEPTH-1:0] O3L3_data,

  // start and done signals
  input wire start,
  output logic keypoints_done

  // // this writes the {x,y, octave, dog_image} values for each keypoint
  // // currently the width for keypoint data should be 15 (6+6+2+1)
  // output logic [($clog2(NUMBER_KEYPOINTS)) - 1:0] keypoint_address,
  // output logic [((2*$clog2(DIMENSION)) + $clog2(NUMBER_OCTAVES) + $clog2(DOG_IMAGES_PER_OCTAVE))- 1:0] keypoint_data,
  // output logic write_keypoint_enable,

  );
  local parameter DIMENSION = TOP_HEIGHT;

  // DOG O1L1L2 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT*TOP_WIDTH)) //we expect a 64*64 image with 4096 pixels total
    O1L1L2 (
    .addra(O1L1L2_address),
    .clka(clk),
    .wea(O1L1L2_wea),
    .dina(O1L1L2_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O1L1L2_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O1L1L2_read_data)
  );
  
  // DOG O1L2L3 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT*TOP_WIDTH)) //we expect a 64*64 image with 4096 pixels total
    O1L1L2 (
    .addra(O1L2L3_address),
    .clka(clk),
    .wea(O1L2L3_wea),
    .dina(O1L2L3_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O1L2L3_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O1L2L3_read_data)
  );


  // Diff of Gaussian module for Octave 1 between L1, L2
  logic O1_DOG_L1L2_done;
  logic O1_DOG_L2L3_done;


  // TODO: transition addresses!!!
  // assign O1L1_read_addr = O1L1L2_address;
  // assign O1L2_read_addr = O1L1L2_address;
  logic [1:0] O1L1L2_state;
  logic [1:0] O1L2L3_state;
  dog #(.DIMENSION(TOP_HEIGHT)) O1_DOG_L1L2 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(start),//we can start populating this BRAM first
  .sharper_pix(O1L1_data),
  .fuzzier_pix(O1L2_data),
  .done(O1_DOG_L1L2_done),
  .address(O1L1L2_address),
  .data_out(O1L1L2_data_write),
  .wea(O1L1L2_wea),
  .state_num(O1L1L2_state)
  );

  dog #(.DIMENSION(TOP_HEIGHT)) O1_DOG_L2L3 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(O1_DOG_L1L2_done),// start populating this BRAM when the previous DOG BRAM is done
  .sharper_pix(O1L2_data),
  .fuzzier_pix(O1L3_data),
  .done(O1_DOG_L2L3_done),
  .address(O1L2L3_address),
  .data_out(O1L2L3_data_write),
  .wea(O1L2L3_wea),
  .state_num(O1L2L3_state)
  );


// Once Diff of G is done, find the extrema from that BRAM
// this sets up the module
// the actual logic of populating the BRAM is in the always_ff smwhere below
check_extrema #(
  .DIMENSION(DIMENSION)
) finder (
  .clk(clk),
  .rst_in(rst_in),
  .first_data(O1L1L2_read_data),
  .first_address(O1L1L2_read_address),
  .second_data(O1L2L3_read_data),
  .second_address(O1L2L3_read_address),
  .enable(O1_DOG_done),
  .x(O1_keypt_x),
  .y(O1_keypt_y),
  .first_is_extremum(O1_L1L2_extremum),
  .second_is_extremum(O1_L2L3_extremum),
  .done_checking(O1_key_done)
  // .state_number(module_state),
  // .first_is_max(first_is_max),
  // .first_is_min(first_is_min),
  // .second_is_max(second_is_max),
  // .second_is_min(second_is_min),
  // .read_x(read_x),
  // .read_y(read_y),
  // .read(read)
  );





endmodule // find_keypoints


`default_nettype wire