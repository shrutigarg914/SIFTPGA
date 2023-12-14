`timescale 1ns / 1ps
`default_nettype none

module generate_descriptors #(
  parameter DIMENSION = 64,
  parameter NUMBER_DESCRIPTORS = 4000, 
  parameter NUMBER_KEYPOINTS = 1000, 
  parameter NUMBER_OCTAVES = 3,
  parameter BIT_DEPTH = 8,
  parameter PATCH_SIZE = 4
  ) (
    
  input wire clk,
  input wire rst_in,


  // For all descriptors
  output logic [$clog2(NUMBER_DESCRIPTORS)-1:0] desc_write_addr,
  output logic desc_wea,
  output logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2)+ 1)*8-1:0] desc_out,  // 4 by 4 --> 2 by 2 subpatches 
                        // --> 4 total orientations --> max 2 bits each for each of 8 possible values
  
  // keypoint BRAM handles
    output logic [$clog2(1000)-1:0] key_read_addr,
    input wire [(2*$clog2(NUMBER_KEYPOINTS)):0] keypoint_read,


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
    output logic [$clog2(DIMENSION / 4*DIMENSION / 4)-1:0] O3L1_x_address,
    output logic [$clog2(DIMENSION /4*DIMENSION / 4)-1:0] O3L1_y_address,

    input wire signed [BIT_DEPTH-1:0] O3L2_x_grad,
    input wire signed [BIT_DEPTH-1:0] O3L2_y_grad,
    output logic [$clog2(DIMENSION / 4*DIMENSION/4)-1:0] O3L2_x_address,
    output logic [$clog2(DIMENSION/4*DIMENSION/4)-1:0] O3L2_y_address,
    output logic [1:0] octave_state_num,
    output logic [3:0] generic_state_num,


  // start and done signals
  input wire start,
  output logic descriptors_done


  );
  parameter HEIGHT = DIMENSION; 
  parameter WIDTH = DIMENSION;

  // https://lerner98.medium.com/implementing-sift-in-python-36c619df7945
  // imitating this when finding the coordinates for patches
  typedef enum {IDLE=0, READ=1, START_HISTOGRAM=2, PATCH_ONE=3, PATCH_TWO=4, PATCH_THREE=5, PATCH_FOUR=6, FINISH=7} module_state;
  module_state state;
  typedef enum {O1=0, O2=1, O3=2} octave_state;
  octave_state octave;
  // logic [1:0] octave_state_num;
  always_comb begin
    octave_state_num = (octave==O1) ? 0 : (octave==O2) ? 1'b1 : 2'b10;
    if (state==IDLE) begin
      generic_state_num = 0;
    end else if (state==READ) begin
      generic_state_num = 1'b1;
    end else if (state==START_HISTOGRAM) begin
      generic_state_num = 2'b10;
    end else if (state==PATCH_ONE) begin
      generic_state_num = 2'b11;
    end else if (state==PATCH_TWO) begin
      generic_state_num = 3'b100;
    end else if (state==PATCH_THREE) begin
      generic_state_num = 3'b101;
    end else if (state==PATCH_FOUR) begin
      generic_state_num = 3'b110;
    end else if (state==FINISH) begin
      generic_state_num = 3'b111;
    end else begin
      generic_state_num = 4'b1000;
    end
  end
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

  // logic to switch between levels in the same Octave
  always_comb begin
      O1L2_x_address = O1_x_address;
      O1L1_x_address = O1_x_address;
      O1L2_y_address = O1_y_address;
      O1L1_y_address = O1_y_address;

      O2L2_x_address = O2_x_address;
      O2L1_x_address = O2_x_address;
      O2L2_y_address = O2_y_address;
      O2L1_y_address = O2_y_address;

      O3L2_x_address = O3_x_address;
      O3L1_x_address = O3_x_address;
      O3L2_y_address = O3_y_address;
      O3L1_y_address = O3_y_address;

      O1_x_grad = (level) ? O1L2_x_grad : O1L1_x_grad;
      O1_y_grad = (level) ? O1L2_y_grad : O1L1_y_grad;
      O2_x_grad = (level) ? O2L2_x_grad : O2L1_x_grad;
      O2_y_grad = (level) ? O2L2_y_grad : O2L1_y_grad;
      O3_x_grad = (level) ? O3L2_x_grad : O3L1_x_grad;
      O3_y_grad = (level) ? O3L2_y_grad : O3L1_y_grad;
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
    .y_grad_in(O1_y_grad),
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
    .y_grad_in(O2_y_grad),
    .x_read_addr(O2_x_address),
    .y_read_addr(O2_y_address),
    // start and done signals
    .start(O2_histogram_ea),
    .histogram_done(O2_histogram_done) // one cycle done signal
  );

  logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2) + 1)*8-1:0] O3_histogram_out;
  logic [$clog2(WIDTH/4)-1:0] O3_x_coord;
  logic [$clog2(HEIGHT/4)-1:0] O3_y_coord;
  logic O3_histogram_ea, O3_histogram_done;

histogram #(
  .WIDTH(DIMENSION/4),
  .HEIGHT(DIMENSION/4)
) O3_hist (
    .clk_in(clk),
    .rst_in(rst_in),
    .histogram_out(O3_histogram_out),
    // coordinates of the top left pixel of the patch
    .x(O3_x_coord),
    .y(O3_y_coord),
    // handles to read from the gradient pyramid
    .x_grad_in(O3_x_grad),
    .y_grad_in(O3_y_grad),
    .x_read_addr(O3_x_address),
    .y_read_addr(O3_y_address),
    // start and done signals
    .start(O3_histogram_ea),
    .histogram_done(O3_histogram_done) // one cycle done signal
  );
  // logic to switch handles used in the always_ff block depending on what octave we are in 
  logic histogram_ea;


  always_comb begin

    O1_histogram_ea = (octave==O1) ? histogram_ea : 0;
    O2_histogram_ea = (octave==O2) ? histogram_ea : 0;
    O3_histogram_ea = (octave==O3) ? histogram_ea : 0;

    desc_wea = (octave==O1) ? O1_histogram_done : (octave==O2) ? O2_histogram_done : (octave==O3) ? O3_histogram_done : 0;
    desc_out = (octave==O1) ? O1_histogram_out : (octave==O2) ? O2_histogram_out : (octave==O3) ? O3_histogram_out : 0;
    
    O1_x_coord = x;
    O1_y_coord = y;
    O2_x_coord = x;
    O2_y_coord = y;
    O3_x_coord = x;
    O3_y_coord = y;
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
                  descriptors_done <= 0;
                  // set keypt address to zero, go read the keypt at the address
              end else begin
                descriptors_done <= 0;
              end
              READ : if (read_counter==2'b10) begin
                  if (keypoint_read==13'd0) begin
                    key_read_addr <= key_read_addr + 1'b1;
                    read_counter <= 0;
                    case(octave)
                      O1 : octave <= O2;// why do we never hit FINISH?
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
                x <= x - PATCH_SIZE / 2;
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