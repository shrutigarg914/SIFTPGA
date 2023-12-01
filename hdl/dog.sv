`timescale 1ns / 1ps
`default_nettype none

// WARNING THE DOG PYRAMIDS ARE GOING TO HAVE SIGNED VALUES
// this module takes a signal for when an Octave's BRAM is ready 
// parameterized by the size of the image corresponding to the octave we're at
// assumption our image dimensions are always square (DIMENSION * DIMENSION)
// also assumption is that this module basically owns the BRAM once it has been written to.
// the only way this can happen is if we pipeline such that the writer writes using a set of pointers
// and the reader reads using another set
// and at every pipeline cycle, we switch which BRAM variables these pointers are reading or writing to
// otherwise we will end up with multiple drivers to each BRAM's input/outputs
module dog #(parameter DIMENSION) (
  input wire clk,
  input wire rst_in,//sys_rst
  input wire bram_ready,
  input wire [7:0] sharper_pix,
  input wire [7:0] fuzzier_pix,
  output logic busy,
  output logic [11:0] address,
  output logic signed [8:0] data_out,
  output logic wea,
  output logic [1:0] state_num
  );
  typedef enum {INACTIVE=0, WAIT=1, WRITE=2} module_state;
  module_state state; 
  parameter BRAM_LENGTH = DIMENSION*DIMENSION -1;
  logic [1:0] counter;
  logic signed [8:0] sharp_sign;
  logic signed [8:0] fuzz_sign;
  logic write;
  logic old_bram;
  // wait for two cycles for read
  // only need the one cycle for write
    always_ff @(posedge clk) begin
      old_bram <= bram_ready;
      if (rst_in) begin
        state <= INACTIVE;
        state_num <= 0;
        counter <= 0;
        address <= 0;
        busy<=1'b0;
        write <= 1'b0;
        wea <= 0;
      end else begin
        case(state)
        INACTIVE: if (bram_ready & ~old_bram) begin
            busy <= 1'b1;
            state <= WAIT;
            state_num <= 1'b1;
            address <= 0;
            counter <= 0;
            wea <= 0;
        end
        WAIT: if (counter==2'b10) begin
          state <= WRITE;
          counter <= 0;
          state_num <= 2'b10;
          sharp_sign <= {1'b0, sharper_pix};
          fuzz_sign <= {1'b0, fuzzier_pix};
        end else begin
          counter <= counter +1;
        end
        WRITE: if (~write) begin
          write <= 1'b1;
          // data_out <= fuzzier_pix;
          data_out <= sharp_sign - fuzz_sign;
          wea<= 1'b1;
        end else begin
          write <= 1'b0;
          wea <= 1'b0;
          if (address==BRAM_LENGTH) begin
            address <= 0;
            state <= INACTIVE;
            state_num <= 1'b0;
            busy <= 1'b0;
          end else begin
            address <= address + 1'b1;
            state <= WAIT;
            state_num <= 1'b1;
          end
        end
        endcase
      end
    end



  //   xilinx_true_dual_port_read_first_2_clock_ram #(
  //   .RAM_WIDTH(9), // we expect 8 bit greyscale images
  //   .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 128*128 image with 16384 pixels total
  //   pixel_bram (
  //   .addra(sharper_img),
  //   .clka(clk),
  //   .wea(0),
  //   .dina(),
  //   .ena(1'b1),
  //   .regcea(1'b1),
  //   .rsta(rst_in),
  //   .douta(), //never read from this side
  //   .addrb(blurrier_img),// transformed lookup pixel
  //   .dinb(),
  //   .clkb(clk),
  //   .web(1'b0),
  //   .enb(1'b1),
  //   .rstb(rst_in),
  //   .regceb(1'b1),
  //   .doutb(pixel_out)
  // );

  // xilinx_true_dual_port_read_first_2_clock_ram #(
  //   .RAM_WIDTH(9), // we expect 8 bit greyscale images
  //   .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 128*128 image with 16384 pixels total
  //   dog_bram (
  //   .addra(sharper_img),
  //   .clka(clk),
  //   .wea(0),
  //   .dina(),
  //   .ena(1'b1),
  //   .regcea(1'b1),
  //   .rsta(rst_in),
  //   .douta(), //never read from this side
  //   .addrb(blurrier_img),// transformed lookup pixel
  //   .dinb(),
  //   .clkb(clk),
  //   .web(1'b0),
  //   .enb(1'b1),
  //   .rstb(rst_in),
  //   .regceb(1'b1),
  //   .doutb(pixel_out)
  // );


  
endmodule // top_level

`default_nettype wire
