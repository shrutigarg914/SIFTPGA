`timescale 1ns / 1ps
`default_nettype none

// dummy histogram header
module histogram #(
  parameter WIDTH = 64,
  parameter HEIGHT = 64,
  parameter BIT_DEPTH = 8,
  parameter PATCH_SIZE = 4
  ) (
    input wire clk_in,
    input wire rst_in,

    // the handle to output the histogram to
    // output logic wea,
    output logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2) + 1)*8-1:0] histogram_out,  // 4 by 4 --> 2 by 2 subpatches 
                            // --> 4 total orientations --> max 2 bits each for each of 8 possible values
    
    // coordinates of the top left pixel of the patch
    input wire [$clog2(WIDTH)-1:0] x,
    input wire [$clog2(HEIGHT)-1:0] y,

    // handles to read from the gradient pyramid
    input wire signed [BIT_DEPTH-1:0] x_grad_in,
    input wire signed [BIT_DEPTH-1:0] y_grad_in,
    output logic [$clog2(WIDTH*HEIGHT)-1:0] x_read_addr,
    output logic [$clog2(WIDTH*HEIGHT)-1:0] y_read_addr,

    // start and done signals
    input wire start,
    output logic histogram_done // one cycle done signal
  );

  gradient_orientation #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .BIT_DEPTH(BIT_DEPTH)) 
  orientation (
    .clk_in(clk_in), .rst_in(rst_in),
    .x_read_addr(x_read_addr),
    .x_read_addr_valid(),
    .x_pixel_in(x_grad_in),
    .y_read_addr(y_read_addr),
    .y_read_addr_valid(),
    .y_pixel_in(y_grad_in),
    .center_addr_x(center_addr_x),
    .center_addr_y(center_addr_y),
    .valid_in(orientation_valid_in),
    .valid_out(orientation_valid_out),
    .bin_out(bin_out),
    .state_num()
  );
  logic [$clog2(WIDTH)-1:0] center_addr_x;
  logic [$clog2(HEIGHT)-1:0] center_addr_y;
  logic orientation_valid_in;
  logic orientation_valid_out;
  logic [2:0] bin_out;
  logic save_to_hist;
  logic last_save;

  typedef enum {IDLE=0, TOPLEFT=1, TOPRIGHT=2, BOTLEFT=3, BOTRIGHT=4} module_state;
  module_state state;

  // assuming only keypoints that are far enough from the edge are passed in
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      center_addr_x <= 0;
      center_addr_y <= 0;
      orientation_valid_in <= 0;
      histogram_done <= 0;
      // wea <= 0;
      histogram_out <= 0;
      save_to_hist <= 0;
      last_save <= 0;
    end else begin
      if (orientation_valid_in) begin
        orientation_valid_in <= 0;
      end
      if (histogram_done) begin
        histogram_done <= 0;
      end
      if (save_to_hist) begin
        save_to_hist <= 0;
        case (bin_out)
          3'b000: begin
            histogram_out[2:0] <= histogram_out[2:0] + 1;
          end
          3'b001: begin
            histogram_out[5:3] <= histogram_out[5:3] + 1;
          end
          3'b010: begin
            histogram_out[8:6] <= histogram_out[8:6] + 1;
          end
          3'b011: begin
            histogram_out[11:9] <= histogram_out[11:9] + 1;
          end
          3'b100: begin
            histogram_out[14:12] <= histogram_out[14:12] + 1;
          end
          3'b101: begin
            histogram_out[17:15] <= histogram_out[17:15] + 1;
          end
          3'b110: begin
            histogram_out[20:18] <= histogram_out[20:18] + 1;
          end
          3'b111: begin
            histogram_out[23:21] <= histogram_out[23:21] + 1;
          end
          default: begin
          end
        endcase

        if (last_save) begin
          last_save <= 0;
          histogram_done <= 1;
        end
      end
      case (state)
        IDLE: begin
          if (start) begin
            histogram_out <= 0;
            center_addr_x <= x;
            center_addr_y <= y;
            orientation_valid_in <= 1;
            state <= TOPLEFT;
          end
        end
        TOPLEFT: begin
          if (orientation_valid_out) begin
            // add to histogram
            save_to_hist <= 1;

            // start next
            center_addr_x <= x+1;
            center_addr_y <= y;
            orientation_valid_in <= 1;
            state <= TOPRIGHT;
          end
        end
        TOPRIGHT: begin
          if (orientation_valid_out) begin
            // add to histogram
            save_to_hist <= 1;

            // start next
            center_addr_x <= x;
            center_addr_y <= y+1;
            orientation_valid_in <= 1;
            state <= BOTLEFT;
          end
        end
        BOTLEFT: begin
          if (orientation_valid_out) begin
            // add to histogram
            save_to_hist <= 1;

            // start next
            center_addr_x <= x+1;
            center_addr_y <= y+1;
            orientation_valid_in <= 1;
            state <= BOTRIGHT;
          end
        end
        BOTRIGHT: begin
          if (orientation_valid_out) begin
            // add to histogram
            save_to_hist <= 1;

            last_save <= 1;
            state <= IDLE;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
  
endmodule // histogram


`default_nettype wire
