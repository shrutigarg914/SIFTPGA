`timescale 1ns / 1ps
`default_nettype none

// WARNING THE GRADIENTS ARE GOING TO HAVE SIGNED VALUES
module gradient_image #(
  parameter WIDTH=64,
  parameter HEIGHT=64,
  parameter BIT_DEPTH=8
  ) (
  input wire clk_in,
  input wire rst_in,

  // connect to BRAM that we are reading from
  output logic [$clog2(WIDTH * HEIGHT)-1:0] ext_read_addr,
  output logic ext_read_addr_valid,
  input wire [BIT_DEPTH-1:0] ext_pixel_in,

  // connect to BRAM that we are writing to for x gradient
  output logic [$clog2(WIDTH * HEIGHT)-1:0] x_write_addr,
  output logic x_write_valid,
  output logic [BIT_DEPTH-1:0] x_pixel_out, // signed

  // connect to BRAM that we are writing to for y gradient
  output logic [$clog2(WIDTH * HEIGHT)-1:0] y_write_addr,
  output logic y_write_valid,
  output logic [BIT_DEPTH-1:0] y_pixel_out, // signed

  input wire start_in, // one clock cycle signal high when starting graident
  output logic gradient_done // one clock cycle signal high when finishing gradient
);
  typedef enum {IDLE=0, READ_X1=1, READ_X2=2, WRITE_X=3, READ_Y1=4, READ_Y2=5, WRITE_Y=6} module_state;
  module_state state; 
  logic signed [BIT_DEPTH:0] pixel1_signed;
  logic signed [BIT_DEPTH:0] pixel2_signed;
  logic busy;
  logic [$clog2(WIDTH)-1:0] center_addr_x;
  logic [$clog2(HEIGHT)-1:0] center_addr_y;

  logic [1:0] ext_read_addr_valid_pipe;
  always_ff @(posedge clk_in) begin
    ext_read_addr_valid_pipe[0] = ext_read_addr_valid;
    ext_read_addr_valid_pipe[1] = ext_read_addr_valid_pipe[0];
  end

  // wait for two cycles for read
  // only need the one cycle for write
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      busy <= 0;
      center_addr_x <= 0;
      center_addr_y <= 0;
      gradient_done <= 0;
    end else begin
      if (ext_read_addr_valid) begin
        ext_read_addr_valid <= 0;
      end
      if (x_write_valid) begin
        x_write_valid <= 0;
      end
      if (y_write_valid) begin
        y_write_valid <= 0;
      end
      if (gradient_done) begin
        gradient_done <= 0;
      end
      case(state)
        IDLE:
        begin
          if (start_in) begin
            state <= READ_X1;
            center_addr_x <= 0;
            center_addr_y <= 0;
          end
        end
        READ_X1:
        begin
          ext_read_addr <= ((center_addr_x > 0) ? (center_addr_x-1) : center_addr_x) + center_addr_y * WIDTH;
          ext_read_addr_valid <= 1;
          if (ext_read_addr_valid_pipe[1]) begin
            pixel1_signed <= {1'b0, ext_pixel_in};
            state <= READ_X2;
          end
        end
        READ_X2:
        begin
          ext_read_addr <= ((center_addr_x < WIDTH - 1) ? (center_addr_x+1) : center_addr_x) + center_addr_y * WIDTH;
          ext_read_addr_valid <= 1;
          if (ext_read_addr_valid_pipe[1]) begin
            pixel2_signed <= {1'b0, ext_pixel_in};
            state <= WRITE_X;
          end
        end
        WRITE_X:
        begin
          x_write_addr <= center_addr_x + center_addr_y * WIDTH;
          x_pixel_out <= ((pixel2_signed - pixel1_signed) >>> 1);
          x_write_valid <= 1;
          state <= READ_Y1;
        end
        READ_Y1:
        begin
          ext_read_addr <= center_addr_x + ((center_addr_y > 0) ? (center_addr_y-1) : center_addr_y) * WIDTH;
          ext_read_addr_valid <= 1;
          if (ext_read_addr_valid_pipe[1]) begin
            pixel1_signed <= {1'b0, ext_pixel_in};
            state <= READ_Y2;
          end
        end
        READ_Y2:
        begin
          ext_read_addr <= center_addr_x + ((center_addr_y < HEIGHT - 1) ? (center_addr_y+1) : center_addr_y) * WIDTH;
          ext_read_addr_valid <= 1;
          if (ext_read_addr_valid_pipe[1]) begin
            pixel2_signed <= {1'b0, ext_pixel_in};
            state <= WRITE_Y;
          end
        end
        WRITE_Y:
        begin
          y_write_addr <= center_addr_x + center_addr_y * WIDTH;
          y_pixel_out <= ((pixel2_signed - pixel1_signed) >>> 1);
          y_write_valid <= 1;
          if (center_addr_x == WIDTH - 1) begin
            if (center_addr_y == HEIGHT - 1) begin
              center_addr_x <= 0;
              center_addr_y <= 0;
              gradient_done <= 1;
              state <= IDLE;
            end else begin
              center_addr_x <= 0;
              center_addr_y <= center_addr_y + 1;
              state <= READ_X1;
            end
          end else begin
            center_addr_x <= center_addr_x + 1;
            state <= READ_X1;
          end
        end
      endcase
    end
  end
  
endmodule // top_level

`default_nettype wire
