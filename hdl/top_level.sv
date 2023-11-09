`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire uart_rxd,
  output logic uart_txd
  );
  // logic sys_rst, tx, rx;
  // assign sys_rst = btn[0];
  assign tx = uart_txd;
  assign rx = uart_rxd;


  logic [$clog2(128*128)-1:0] image_addr;

  manta inpt_img (
    .clk(clk_100mhz),

    .rx(rx),
    .tx(tx),
    
    .image_memory_clk(clk_100mhz), 
    .image_memory_addr(image_addr), 
    .image_memory_din(), 
    .image_memory_dout(pixel_value), 
    .image_memory_we(1'b0)
  );

  logic [11:0] pixel_value;
  logic [3:0] pixel_r, pixel_g, pixel_b;
  logic [7:0] greyscale;
  // lol i can't just do this math here
  // FIX THIS:?
  assign greyscale = pixel_r + pixel_g + pixel_b;
  // logic [] write_address

  manta output_img (
    .clk(clk_100mhz),

    .rx(rx),
    .tx(tx),
    
    .image_memory_clk(clk_100mhz), 
    .image_memory_addr(image_addr), 
    .image_memory_din(greyscale), 
    .image_memory_dout(), 
    .image_memory_we(1'b1)
  );

  always_ff @(posedge clk_100mhz) begin
    if (image_addr < 128*128) begin
      image_addr <= image_addr + 1;
    end else begin
      image_addr <= 0;
    end
  end
  
endmodule // top_level


`default_nettype wire
