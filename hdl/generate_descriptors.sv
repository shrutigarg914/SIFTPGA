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
    input wire signed [BIT_DEPTH-1:0] O1L1_x_grad,
    input wire signed [BIT_DEPTH-1:0] O1L1_y_grad,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L1_x_address,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O1L2_x_grad,
    input wire signed [BIT_DEPTH-1:0] O1L2_y_grad,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L2_x_address,
    output logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L2_y_address,

    input wire signed [BIT_DEPTH-1:0] O2L1_x_grad,
    input wire signed [BIT_DEPTH-1:0] O2L1_y_grad,
    output logic [$clog2(DIMENSION / 2*DIMENSION / 2)-1:0] O2L1_x_address,
    output logic [$clog2(DIMENSION /2*DIMENSION / 2)-1:0] O2L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O2L2_x_grad,
    input wire signed [BIT_DEPTH-1:0] O2L2_y_grad,
    output logic [$clog2(DIMENSION / 2*DIMENSION/2)-1:0] O2L2_x_address,
    output logic [$clog2(DIMENSION/2*DIMENSION/2)-1:0] O2L2_y_address,

    input wire signed [BIT_DEPTH-1:0] O3L1_x_grad,
    input wire signed [BIT_DEPTH-1:0] O3L1_y_grad,
    output logic [$clog2(DIMENSION / 2*DIMENSION / 2)-1:0] O3L1_x_address,
    output logic [$clog2(DIMENSION /2*DIMENSION / 2)-1:0] O3L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O3L2_x_grad,
    input wire signed [BIT_DEPTH-1:0] O3L2_y_grad,
    output logic [$clog2(DIMENSION / 4*DIMENSION/4)-1:0] O3L2_x_address,
    output logic [$clog2(DIMENSION/4*DIMENSION/4)-1:0] O3L2_y_address,


  // start and done signals
  input wire start,
  output logic descriptors_done


  );
  parameter TOP_HEIGHT = DIMENSION; 
  parameter TOP_WIDTH = DIMENSION;

  // https://lerner98.medium.com/implementing-sift-in-python-36c619df7945
  // imitating this when finding the coordinates for patches
  typedef enum {IDLE=0, READ=1, START_HISTOGRAM=2, PATCH_ONE=3, PATCH_TWO=4, PATCH_THREE=5, PATCH_FOUR=6} module_state;
  module_state state;
  typedef enum {O1=0, O2=1, O3=2} octave_state;
  octave_state octave;
  logic level;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] O1_x_address;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] O1_y_address;
  logic signed [BIT_DEPTH-1:0] O1_x_grad;
  logic signed [BIT_DEPTH-1:0] O1_y_grad;

  logic [$clog2(DIMENSION /2*DIMENSION /2)-1:0] O2_x_address;
  logic [$clog2(DIMENSION /2*DIMENSION /2)-1:0] O2_y_address;
  logic signed [BIT_DEPTH-1:0] O2_x_grad;
  logic signed [BIT_DEPTH-1:0] O2_y_grad;

  logic [$clog2(DIMENSION /4*DIMENSION /4)-1:0] O3_x_address;
  logic [$clog2(DIMENSION /4*DIMENSION /4)-1:0] O3_y_address;
  logic signed [BIT_DEPTH-1:0] O3_x_grad;
  logic signed [BIT_DEPTH-1:0] O3_y_grad;

  always_comb begin
    case(octave)
        O1 : begin
            O1_x_address = (level) ? O1L2_x_address : O1L1_x_address;
            O1_y_address = (level) ? O1L2_y_address : O1L1_y_address;
            O1_x_grad = (level) ? O1L2_x_grad : O1L1_x_grad;
            O1_y_grad = (level) ? O1L2_y_grad : O1L1_y_grad;

            
        end
        O2 : begin
            O2_x_address = (level) ? O2L2_x_address : O2L1_x_address;
            O2_y_address = (level) ? O2L2_y_address : O2L1_y_address;
            O2_x_grad = (level) ? O2L2_x_grad : O2L1_x_grad;
            O2_y_grad = (level) ? O2L2_y_grad : O2L1_y_grad;

            desc_wea = O2_histogram_done;
        end
        O3 : begin
            O3_x_address = (level) ? O3L2_x_address : O3L1_x_address;
            O3_y_address = (level) ? O3L2_y_address : O3L1_y_address;
            O3_x_grad = (level) ? O3L2_x_grad : O3L1_x_grad;
            O3_y_grad = (level) ? O3L2_y_grad : O3L1_y_grad;

            desc_wea = O3_histogram_done;
        end
    endcase
  end

  logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2) + 1)*8-1:0] O1_histogram_out;
  logic [$clog2(WIDTH)-1:0] O1_x_coord;
  logic [$clog2(HEIGHT)-1:0] O1_y_coord;
  logic O1_histogram_ea, O1_histogram_done;

histogram #(
  .WIDTH(DIMENSION),
  .HEIGHT(DIMENSION)
) O1_hist (
    .clk_in(clk),
    .rst_in(rst_in),
    .histogram_out(O1_histogram_out),
    // coordinates of the top left pixel of the patch
    .x(O1_x_coord),
    .y(O1_y_coord),
    // handles to read from the gradient pyramid
    .x_grad_in(O1_x_grad),
    .y_grad_in(O1_x_grad),
    .x_read_addr(O1_x_address),
    .y_read_addr(O1_y_address),
    // start and done signals
    .start(O1_histogram_ea),
    .histogram_done(O1_histogram_done) // one cycle done signal
  );
  
  logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2) + 1)*8-1:0] O2_histogram_out;
  logic [$clog2(WIDTH/2)-1:0] O2_x_coord;
  logic [$clog2(HEIGHT/2)-1:0] O2_y_coord;
  logic O2_histogram_ea, O2_histogram_done;

histogram #(
  .WIDTH(DIMENSION/2),
  .HEIGHT(DIMENSION/2)
) O2_hist (
    .clk_in(clk),
    .rst_in(rst_in),
    .histogram_out(O2_histogram_out),
    // coordinates of the top left pixel of the patch
    .x(O2_x_coord),
    .y(O2_y_coord),
    // handles to read from the gradient pyramid
    .x_grad_in(O2_x_grad),
    .y_grad_in(O2_x_grad),
    .x_read_addr(O2_x_address),
    .y_read_addr(O2_y_address),
    // start and done signals
    .start(O2_histogram_ea),
    .histogram_done(O2_histogram_done) // one cycle done signal
  );

  logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2) + 1)*8-1:0] O3_histogram_out;
  logic [$clog2(WIDTH/2)-1:0] O3_x_coord;
  logic [$clog2(HEIGHT/2)-1:0] O3_y_coord;
  logic O3_histogram_ea, O3_histogram_done;

histogram #(
  .WIDTH(DIMENSION/2),
  .HEIGHT(DIMENSION/2)
) O3_hist (
    .clk_in(clk),
    .rst_in(rst_in),
    .histogram_out(O3_histogram_out),
    // coordinates of the top left pixel of the patch
    .x(O3_x_coord),
    .y(O3_y_coord),
    // handles to read from the gradient pyramid
    .x_grad_in(O3_x_grad),
    .y_grad_in(O3_x_grad),
    .x_read_addr(O3_x_address),
    .y_read_addr(O3_y_address),
    // start and done signals
    .start(O3_histogram_ea),
    .histogram_done(O3_histogram_done) // one cycle done signal
  );

  logic histogram_ea;
  always_comb begin
    case(octave)
      O1 : begin
        O1_histogram_ea = histogram_ea;
        desc_wea = O1_histogram_done;
        O1_x_coord = x;
        O1_y_coord = y;
      end
      O2 : begin
        O2_histogram_ea = histogram_ea;
        desc_wea = O2_histogram_done;
        O2_x_coord = x;
        O2_y_coord = y;
      end
      O3 : begin
        O3_histogram_ea = histogram_ea;
        desc_wea = O3_histogram_done;
        O3_x_coord = x;
        O3_y_coord = y;
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
          histogram_ea <= 1'b0;
          desc_write_addr <= 0;
      end else begin
          case(state)
              IDLE : if (start) begin
                  key_read_addr <= 0;
                  state <= READ;
                  read_counter <= 0;
                  octave <= O1;
                  histogram_ea <= 1'b0;
                  // set keypt address to zero, go read the keypt at the address
              end else begin
                descriptors_done <= 0;
              end
              READ : if (read_counter==2'b10) begin
                  if (keypoint_read==13'd0) begin
                    key_read_addr <= key_read_addr + 1'b1;
                    read_counter <= 0;
                    case(octave)
                      O1 : octave <= O2;
                      O2 : octave <= O3;
                      O3 : state <= FINISH;
                    endcase
                  end else begin
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
                    state <= START_HISTOGRAM;
                  end
              end else begin
                  read_counter <= read_counter + 1'b1;
              end
              START_HISTOGRAM : begin
                if (x>(PATCH_SIZE/2-1)) begin
                    x <= x - PATCH_SIZE/2;
                end else begin
                    x <= 0;
                end
                if (y>(PATCH_SIZE/2-1)) begin
                    y <= y - PATCH_SIZE/2;
                end else begin
                    y <= 0;
                end
                histogram_ea <= 1'b1;
                state <= PATCH_ONE;
              end
              PATCH_ONE : if (desc_wea) begin
                x <= x + PATCH_SIZE /2;
                desc_write_addr <= desc_write_addr + 1'b1;
                histogram_ea <= 1'b1;
                state <= PATCH_TWO;
              end else begin
                histogram_ea <= 1'b0;
              end
              PATCH_TWO : if (desc_wea) begin
                y <= y + PATCH_SIZE / 2;
                desc_write_addr <= desc_write_addr + 1'b1;
                histogram_ea <= 1'b1;
                state <= PATCH_THREE;
              end else begin
                histogram_ea <= 1'b0;
              end
              PATCH_THREE : if (desc_wea) begin
                read_x <= read_x - PATCH_SIZE / 2;
                desc_write_addr <= desc_write_addr + 1'b1;
                histogram_ea <= 1'b1;
                state <= PATCH_FOUR;
              end else begin
                histogram_ea <= 1'b0;
              end
              PATCH_FOUR : if (desc_wea) begin
                desc_write_addr <= desc_write_addr + 1'b1;
                if (key_read_addr < DIMENSION * DIMENSION - 1'b1 ) begin
                  key_read_addr <= key_read_addr + 1'b1;
                  state <= READ;
                  read_counter <= 0;
                end else begin
                  state <= FINISH;
                end
              end else begin
                histogram_ea <= 1'b0;
              end
              FINISH : begin
                descriptors_done <= 1'b1;
                state <= IDLE;
              end
          endcase
      end
  end


endmodule // find_keypoints


`default_nettype wire