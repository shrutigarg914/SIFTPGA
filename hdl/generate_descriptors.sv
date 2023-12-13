`timescale 1ns / 1ps
`default_nettype none

// keypoint BRAM is assumed to be x,y in each row
// so 2 * $clog2(DIMENSION) WIDTH

// lets first find keypoints from only one scale!
// GOAL: given the gaussian pyramid, write the keypoint BRAM

module generate_descriptors #(
  parameter DIMENSION = 64,
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter IMG_BIT_DEPTH = 8,
  parameter PATCH_SIZE = 4
  ) (
    
  input wire clk,
  input wire rst_in,


  // For all descriptors
  output logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] desc_write_addr,
  output logic desc_wea,
  output logic [$clog2(PATCH_SIZE/2 * PATCH_SIZE/2)*8-1:0] desc_out,  // 4 by 4 --> 2 by 2 subpatches 
                        // --> 4 total orientations --> max 2 bits each for each of 8 possible values
  
  // keypoint BRAM handles
    output logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] key_read_addr,
    input logic [(2*$clog2(DIMENSION)):0] keypoint_read,


  // gradient pyramid read handles
    input wire signed [BIT_DEPTH-1:0] O1L1_x,
    input wire signed [BIT_DEPTH-1:0] O1L1_y,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L1_x_address,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O1L2_x,
    input wire signed [BIT_DEPTH-1:0] O1L2_y,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L2_x_address,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L2_y_address,

    input wire signed [BIT_DEPTH-1:0] O2L1_x,
    input wire signed [BIT_DEPTH-1:0] O2L1_y,
    output logic [$clog2(DIMENSION / 2*DIMENSION / 2)-1:0] O2L1_x_address,
    output logic [$clog2(DIMENSION /2*DIMENSION / 2)-1:0] O2L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O2L2_x,
    input wire signed [BIT_DEPTH-1:0] O2L2_y,
    output logic [$clog2(DIMENSION / 2*DIMENSION/2)-1:0] O2L2_x_address,
    output logic [$clog2(DIMENSION/2*DIMENSION/2)-1:0] O2L2_y_address,


  // start and done signals
  input wire start,
  output logic descriptors_done


  );
  parameter TOP_HEIGHT = DIMENSION; 
  parameter TOP_WIDTH = DIMENSION;

  // https://lerner98.medium.com/implementing-sift-in-python-36c619df7945
  // imitating this when finding the coordinates for patches
  typedef enum {IDLE=0, READ=1,} module_state;
  module_state state;
  typedef enum {O1=0, O2=1, O3=2} octave_state;
  octave_state octave;
  logic level;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] hist_x_address;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] hist_y_address;

  // O1=2, O2=3, O3=4

  always_comb begin
    case(octave)
        O1 : begin
            hist_x_address = (level) ? O1L2_x_address : O1L1_x_address;
            hist_y_address = (level) ? O1L2_y_address : O1L1_y_address;
        end
        O2 : begin
            hist_x_address = (level) ? O2L2_x_address : O2L1_x_address;
            hist_y_address = (level) ? O2L2_y_address : O2L1_y_address;
        end
        O3 : begin
            hist_x_address = (level) ? O3L2_x_address : O3L1_x_address;
            hist_y_address = (level) ? O3L2_y_address : O3L1_y_address;
        end
    endcase
  end


  logic [1:0] read_counter;
  logic [$clog2(DIMENSION)-1:0] x;
  logic [$clog2(DIMENSION)-1:0] y;
  always_ff @(posedge clk) begin
      if (rst_in) begin
          state <= IDLE;
          octave <= O1;
          key_read_addr <= 0;
          read_counter <= 0;
      end else begin
          case(state)
              IDLE : if (start) begin
                  key_read_addr <= 0;
                  state <= READ;
                  read_counter <= 0;
                  octave <= O1;
                  // set keypt address to zero, go read the keypt at the address
              end
              READ : if (counter==2'b10) begin
                  level <= keypoint_read[0];
                  case(octave)
                      O1 : begin
                          x <= keypoint_read[12:7];
                          y <= keypoint_read[6:1];
                      end
                      O2 : begin
                          x <= keypoint_read[10:6];
                          y <= keypoint_read[5:1];
                      end
                      O3 : begin
                          x <= keypoint_read[8:5];
                          y <= keypoint_read[4:1];
                      end
                  endcase
                  state <= PATCH_ONE;
              end else begin
                  counter <= counter + 1'b1;
              end
          endcase
      end
  end


endmodule // find_keypoints


`default_nettype wire