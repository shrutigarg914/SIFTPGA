`timescale 1ns / 1ps
`default_nettype none

// angles on boundaries fall counterclockwise
module gradient_orientation #(
  parameter WIDTH=64,
  parameter HEIGHT=64,
  parameter BIT_DEPTH=8
  ) (
  input wire clk_in,
  input wire rst_in,

  // connect to x gradient BRAM that we are reading from
  output logic [$clog2(WIDTH * HEIGHT)-1:0] x_read_addr,
  output logic x_read_addr_valid,
  input wire [BIT_DEPTH-1:0] x_pixel_in,

  // connect to y gradient BRAM that we are reading from
  output logic [$clog2(WIDTH * HEIGHT)-1:0] y_read_addr,
  output logic y_read_addr_valid,
  input wire [BIT_DEPTH-1:0] y_pixel_in,

  input wire [$clog2(WIDTH)-1:0] center_addr_x,
  input wire [$clog2(HEIGHT)-1:0] center_addr_y,

  input wire valid_in, // one clock cycle signal high when center address is ready
  output logic valid_out, // one clock cycle signal high when output is valid
  output logic [2:0] bin_out, // 8 bins total, 3 bits should be enough
  output logic[1:0] state_num
);
  typedef enum {IDLE=0, READ_X=1, READ_Y=2, OUTPUT=3} module_state;
  module_state state;

  always_comb begin
    case (state)
      IDLE: begin
        state_num = 0;
      end
      READ_X: begin
        state_num = 1;
      end
      READ_Y: begin
        state_num = 2;
      end
      OUTPUT: begin
        state_num = 3;
      end
    endcase
  end

  logic [1:0] x_read_addr_valid_pipe;
  logic [1:0] y_read_addr_valid_pipe;
  always_ff @(posedge clk_in) begin
    x_read_addr_valid_pipe[0] <= x_read_addr_valid;
    x_read_addr_valid_pipe[1] <= x_read_addr_valid_pipe[0];
    
    y_read_addr_valid_pipe[0] <= y_read_addr_valid;
    y_read_addr_valid_pipe[1] <= y_read_addr_valid_pipe[0];
  end

  logic [BIT_DEPTH-1:0] x_grad;
  logic [BIT_DEPTH-1:0] y_grad;

  logic [BIT_DEPTH-1:0] x_grad_neg;
  logic [BIT_DEPTH-1:0] y_grad_neg;

  assign x_grad_neg = 0 - x_grad;
  assign y_grad_neg = 0 - y_grad;

  // wait for two cycles for read
  // only need the one cycle for write
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      x_read_addr_valid <= 0;
      x_read_addr <= 0;
      y_read_addr_valid <= 0;
      y_read_addr <= 0;
      valid_out <= 0;
      bin_out <= 0;
    end else begin
      if (x_read_addr_valid) begin
        x_read_addr_valid <= 0;
      end
      if (y_read_addr_valid) begin
        y_read_addr_valid <= 0;
      end
      if (valid_out) begin
        valid_out <= 0;
      end
      case(state)
        IDLE:
        begin
          if (valid_in) begin
            state <= READ_X;
            x_read_addr <= center_addr_x + center_addr_y * WIDTH;
            x_read_addr_valid <= 1;
          end
        end
        READ_X:
        begin
          if (x_read_addr_valid_pipe[1]) begin
            x_grad <= x_pixel_in;
            state <= READ_Y;
            y_read_addr <= center_addr_x + center_addr_y * WIDTH;
            y_read_addr_valid <= 1;
          end
        end
        READ_Y:
        begin
          if (y_read_addr_valid_pipe[1]) begin
            y_grad <= y_pixel_in;
            state <= OUTPUT;
          end
        end
        OUTPUT:
        begin
          if (x_grad[BIT_DEPTH-1] == 0 && y_grad[BIT_DEPTH-1] == 0) begin
            // handle boundary
            if (x_grad == 0 && y_grad != 0) begin
                bin_out <= 2;
            end else begin
                // 8thdrants 0, 1
                if (x_grad > y_grad) begin
                    bin_out <= 0;
                end else begin
                    bin_out <= 1;
                end
            end
          end
          if (x_grad[BIT_DEPTH-1] == 1 && y_grad[BIT_DEPTH-1] == 0) begin
            // handle boundary
            if (x_grad != 0 && y_grad == 0) begin
                bin_out <= 4;
            end else begin
                // 8thdrants 2, 3
                if (x_grad_neg < y_grad) begin
                    bin_out <= 2;
                end else begin
                    bin_out <= 3;
                end
            end
          end
          if (x_grad[BIT_DEPTH-1] == 1 && y_grad[BIT_DEPTH-1] == 1) begin
            // handle boundary
            if (x_grad == 0 && y_grad != 0) begin
                bin_out <= 6;
            end else begin
                // 8thdrants 4, 5
                if (x_grad_neg > y_grad_neg) begin
                    bin_out <= 4;
                end else begin
                    bin_out <= 5;
                end
            end
          end
          if (x_grad[BIT_DEPTH-1] == 0 && y_grad[BIT_DEPTH-1] == 1) begin
            // 8thdrants 6, 7
            if (x_grad < y_grad_neg) begin
                bin_out <= 6;
            end else begin
                bin_out <= 7;
            end
          end
          valid_out <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
  
endmodule // top_level

`default_nettype wire
