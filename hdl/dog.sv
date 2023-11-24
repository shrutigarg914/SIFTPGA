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

  );

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(9), // we expect 8 bit greyscale images
    .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 128*128 image with 16384 pixels total
    dog_bram (
    .addra(sharper_img),
    .clka(clk),
    .wea(0),
    .dina(),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(), //never read from this side
    .addrb(blurrier_img),// transformed lookup pixel
    .dinb(),
    .clkb(clk),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(pixel_out)
  );


  
endmodule // top_level

`default_nettype wire
