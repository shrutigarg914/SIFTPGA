`timescale 1ns / 1ps
`default_nettype none

// a sub module to check for extrema, and owns the address setters for both BRAMs
module read_pixel #(
  parameter BIT_DEPTH = 9,
  parameter DIMENSION = 4
  ) (
  input wire clk,
  input wire rst_in,

  input wire signed [BIT_DEPTH-1:0] first_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address,
  
  input wire signed [BIT_DEPTH-1:0] second_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] second_address,

  input wire input_ready,
  input wire [$clog2(DIMENSION)-1:0] x,
  input wire [$clog2(DIMENSION)-1:0] y,
  output logic busy,
  output logic done// goes high for one cycle when read is done
  );
    typedef enum {IDLE=0, BUSY=1} reader_state;
    reader_state state;

    logic [1:0] counter;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] address;
    assign address = y * DIMENSION + x;
    always_ff @(posedge clk) begin
      if (rst_in) begin
        counter <= 0;
      end else begin
        case(state)
          IDLE: if (input_ready) begin
            state <= BUSY;
            first_address <= address;
            second_address <= address;
            counter <= 0; 
            busy <= 1'b1;
            done <= 1'b0;
          end else begin
            state <= IDLE;
            done <= 1'b0;
          end
          BUSY: if (counter==2'b10) begin
            state <= IDLE;
            done <= 1'b1;
            busy <= 1'b0;
          end else begin
            counter <= counter + 1'b1;
          end
        endcase
      end
    end       
endmodule


`default_nettype wire