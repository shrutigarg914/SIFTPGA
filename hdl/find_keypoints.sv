`timescale 1ns / 1ps
`default_nettype none

// keypoint BRAM is assumed to be x,y in each row
// so 2 * $clog2(DIMENSION) WIDTH

// lets first find keypoints from only one scale!
// GOAL: given the gaussian pyramid, write the keypoint BRAM

module find_keypoints #(
  parameter DIMENSION = 64,
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter DOG_IMAGES_PER_OCTAVE = 2,// the check extrema module currently assumes this is 2 always 
  parameter IMG_BIT_DEPTH = 8
  ) (
  input wire clk,
  input wire rst_in,

  // handles to the keypoint BRAMs

  // FOR all keypoints
  output logic [$clog2(NUMBER_KEYPOINTS)-1:0] key_write_addr,
  output logic key_wea,
  output logic [(2*$clog2(DIMENSION)):0] keypoint_out,

  // stealing the inputs/outputs from gaussian pyramid for consistency in naming
  // we want to read from the pyramid BRAMs, so we need to output addresses and read data
  
  // Octave 1
  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L1_data,

  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L2_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L2_data,
  
  output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L3_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O1L3_data,

  output logic O1_DOG_L2L3_done,

  
  // // Octave 2
  output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L1_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O2L1_data,

  output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L2_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O2L2_data,
  
  output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L3_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O2L3_data,
  
  // // Octave 3
  output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L1_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O3L1_data,

  output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L2_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O3L2_data,
  
  output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L3_read_addr,
  input wire [IMG_BIT_DEPTH-1:0] O3L3_data,

  output logic in_ocatve_3_latched,

  // start and done signals
  input wire start,
  output logic keypoints_done


  );

  parameter TOP_HEIGHT = DIMENSION; 
  parameter TOP_WIDTH = DIMENSION;
  logic signed [IMG_BIT_DEPTH:0] O1L1L2_data_write, O1L2L3_data_write, O1L1L2_read_data, O1L2L3_read_data;
  logic O1L1L2_wea, O1L2L3_wea;
  logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1L2_address, O1L2L3_address, O1L1L2_read_address, O1L2L3_read_address;
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
    O1L2L3 (
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
  // logic O1_DOG_L2L3_done;
  logic O2_DOG_L1L2_done;
  logic O2_DOG_L2L3_done;

  logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L1L2_address, O2L2L3_address, O2L1L2_read_address, O2L2L3_read_address;
  logic signed [IMG_BIT_DEPTH:0] O2L1L2_data_write, O2L2L3_data_write, O2L1L2_read_data, O2L2L3_read_data;
  logic O2L1L2_wea, O2L2L3_wea;
  // DOG O2L1L2 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT / 2 *TOP_WIDTH / 2)) //we expect a 64*64 image with 4096 pixels total
    O2L1L2 (
    .addra(O2L1L2_address),
    .clka(clk),
    .wea(O2L1L2_wea),
    .dina(O2L1L2_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O2L1L2_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O2L1L2_read_data)
  );
  
  // DOG O2L2L3 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT / 2*TOP_WIDTH / 2)) //we expect a 64*64 image with 4096 pixels total
    O2L2L3 (
    .addra(O2L2L3_address),
    .clka(clk),
    .wea(O2L2L3_wea),
    .dina(O2L2L3_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O2L2L3_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O2L2L3_read_data)
  );

  logic O3_DOG_L1L2_done;
  logic O3_DOG_L2L3_done;

  logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L1L2_address, O3L2L3_address, O3L1L2_read_address, O3L2L3_read_address;
  logic signed [IMG_BIT_DEPTH:0] O3L1L2_data_write, O3L2L3_data_write, O3L1L2_read_data, O3L2L3_read_data;
  logic O3L1L2_wea, O3L2L3_wea;
  // DOG O3L1L2 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT / 4 *TOP_WIDTH / 4)) //we expect a 64*64 image with 4096 pixels total
    O3L1L2 (
    .addra(O3L1L2_address),
    .clka(clk),
    .wea(O3L1L2_wea),
    .dina(O3L1L2_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O3L1L2_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O3L1L2_read_data)
  );

  // DOG O3L2L3 BRAM
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(IMG_BIT_DEPTH+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_HEIGHT / 4*TOP_WIDTH / 4)) //we expect a 64*64 image with 4096 pixels total
    O3L2L3 (
    .addra(O3L2L3_address),
    .clka(clk),
    .wea(O3L2L3_wea),
    .dina(O3L2L3_data_write),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(O3L2L3_read_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(O3L2L3_read_data)
  );


  always_comb begin
    O1L1_read_addr = (O1L2L3_busy) ? O1L2L3_address : O1L1L2_address;
    O1L2_read_addr = (O1L2L3_busy) ? O1L2L3_address : O1L1L2_address;
    O1L3_read_addr = (O1L2L3_busy) ? O1L2L3_address : O1L1L2_address;  

    O2L1_read_addr = (O2L2L3_busy) ? O2L2L3_address : O2L1L2_address;
    O2L2_read_addr = (O2L2L3_busy) ? O2L2L3_address : O2L1L2_address;
    O2L3_read_addr = (O2L2L3_busy) ? O2L2L3_address : O2L1L2_address;  

    O3L1_read_addr = (O3L2L3_busy) ? O3L2L3_address : O3L1L2_address;
    O3L2_read_addr = (O3L2L3_busy) ? O3L2L3_address : O3L1L2_address;
    O3L3_read_addr = (O3L2L3_busy) ? O3L2L3_address : O3L1L2_address;  

  end


  logic [1:0] O1L1L2_state;
  logic [1:0] O1L2L3_state;
  logic O1L1L2_busy;
  dog #(.DIMENSION(DIMENSION)) O1_DOG_L1L2 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(start),//we can start populating this BRAM first
  .sharper_pix(O1L1_data),
  .fuzzier_pix(O1L2_data),
  .done(O1_DOG_L1L2_done),
  .address(O1L1L2_address),
  .data_out(O1L1L2_data_write),
  .wea(O1L1L2_wea),
  .state_num(O1L1L2_state),
  .busy(O1L1L2_busy)
  );

  logic O1L2L3_busy;
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
  .state_num(O1L2L3_state),
  .busy(O1L2L3_busy)
  );

  logic [1:0] O2L1L2_state;
  logic [1:0] O2L2L3_state;
  dog #(.DIMENSION(DIMENSION / 2)) O2_DOG_L1L2 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(start),//we can start populating this BRAM first
  .sharper_pix(O2L1_data),
  .fuzzier_pix(O2L2_data),
  .done(O2_DOG_L1L2_done),
  .address(O2L1L2_address),
  .data_out(O2L1L2_data_write),
  .wea(O2L1L2_wea),
  .state_num(O2L1L2_state)
  );

  logic O2L2L3_busy;
  dog #(.DIMENSION(TOP_HEIGHT / 2)) O2_DOG_L2L3 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(O2_DOG_L1L2_done),// start populating this BRAM when the previous DOG BRAM is done
  .sharper_pix(O2L2_data),
  .fuzzier_pix(O2L3_data),
  .done(O2_DOG_L2L3_done),
  .address(O2L2L3_address),
  .data_out(O2L2L3_data_write),
  .wea(O2L2L3_wea),
  .state_num(O2L2L3_state),
  .busy(O2L2L3_busy)
  );

  logic [1:0] O3L1L2_state;
  logic [1:0] O3L2L3_state;
  dog #(.DIMENSION(DIMENSION / 4)) O3_DOG_L1L2 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(start),//we can start populating this BRAM first
  .sharper_pix(O3L1_data),
  .fuzzier_pix(O3L2_data),
  .done(O3_DOG_L1L2_done),
  .address(O3L1L2_address),
  .data_out(O3L1L2_data_write),
  .wea(O3L1L2_wea),
  .state_num(O3L1L2_state)
  );

  logic O3L2L3_busy;
  dog #(.DIMENSION(TOP_HEIGHT / 4)) O3_DOG_L2L3 (
  .clk(clk),
  .rst_in(rst_in),//sys_rst
  .bram_ready(O3_DOG_L1L2_done),// start populating this BRAM when the previous DOG BRAM is done
  .sharper_pix(O3L2_data),
  .fuzzier_pix(O3L3_data),
  .done(O3_DOG_L2L3_done),
  .address(O3L2L3_address),
  .data_out(O3L2L3_data_write),
  .wea(O3L2L3_wea),
  .state_num(O3L2L3_state),
  .busy(O3L2L3_busy)
  );

  logic O1key_wea, O2key_wea, O3key_wea;
  logic [(2*$clog2(DIMENSION / 4)):0] O3_keypoint_out;
  logic [(2*$clog2(DIMENSION / 2)):0] O2_keypoint_out;
  logic [(2*$clog2(DIMENSION)):0] O1_keypoint_out;

// Once Diff of G is done, find the extrema from that BRAM
// this sets up the module
// the actual logic of populating the BRAM is in the always_ff smwhere below
  logic O1_key_done;
  logic O3_key_done;
  assign keypoints_done = O3_key_done;
check_extrema #(
  .DIMENSION(DIMENSION)
) O1_finder (
  .clk(clk),
  .rst_in(rst_in),
  .first_data(O1L1L2_read_data),
  .first_address(O1L1L2_read_address),
  .second_data(O1L2L3_read_data),
  .second_address(O1L2L3_read_address),
  .enable(O1_DOG_L2L3_done),
  .done_checking(O1_key_done),
  .key_wea(O1key_wea),
  .key_out(O1_keypoint_out)
  );

logic O2_key_done;
check_extrema #(
  .DIMENSION(DIMENSION / 2)
) O2_finder (
  .clk(clk),
  .rst_in(rst_in),
  .first_data(O2L1L2_read_data),
  .first_address(O2L1L2_read_address),
  .second_data(O2L2L3_read_data),
  .second_address(O2L2L3_read_address),
  .enable(O1_key_done),
  .done_checking(O2_key_done),
  .key_wea(O2key_wea),
  .key_out(O2_keypoint_out)
  );

  check_extrema #(
    .DIMENSION(DIMENSION /4)
  ) O3_finder (
    .clk(clk),
    .rst_in(rst_in),
    .first_data(O3L1L2_read_data),
    .first_address(O3L1L2_read_address),
    .second_data(O3L2L3_read_data),
    .second_address(O3L2L3_read_address),
    .enable(O2_key_done),
    .done_checking(O3_key_done),
    .key_wea(O3key_wea),
    .key_out(O3_keypoint_out)
    );

  typedef enum {O1=0, O2=1, O3=2} extrema_octave;
  extrema_octave octave;

  always_ff @(posedge clk) begin
    if (rst_in) begin
      octave <= O1;
    end else begin
      if (O1_key_done) begin
        octave <= O2;
      end else if (O2_key_done) begin
        octave <= O3;
      end
    end
  end
  logic in_ocatve_3;

  always_comb begin
    key_wea = (octave==O1) ? O1key_wea : (octave==O2) ? O2key_wea : O3key_wea;
    keypoint_out = (octave==O1) ? O1_keypoint_out : (octave==O2) ? O2_keypoint_out : O3_keypoint_out;
    in_ocatve_3 = (octave==O3) ? 1'b1 : 0;
  end

  logic old_key_wea;
  // logic [(2*$clog2(DIMENSION)):0] key_out;

  always_ff @(posedge clk) begin
    if (rst_in) begin
      key_write_addr <= 0;
      old_key_wea <= 1'b0;
      in_ocatve_3_latched <= 0;
    end else begin
      old_key_wea <= key_wea;
      if (in_ocatve_3) begin
        in_ocatve_3_latched <= 1'b1;
      end
      if (old_key_wea && ~key_wea) begin// falling edge
        key_write_addr <= key_write_addr + 1'b1;
      end
    end
  end



endmodule // find_keypoints


`default_nettype wire