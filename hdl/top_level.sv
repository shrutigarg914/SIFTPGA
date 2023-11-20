`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire uart_rxd,
  input wire [3:0] btn, //all four momentary button switches
  output logic uart_txd
  );
  logic tx, rx, sys_rst;
  assign sys_rst = btn[0];
  assign tx = uart_txd;
  assign rx = uart_rxd;


  logic [$clog2(128*128)-1:0] image_addr;

  manta uart (
    .clk(clk_100mhz),

    .rx(rx),
    .tx(tx),
    
    .image_memory_clk(clk_100mhz), 
    .image_memory_addr(image_addr), 
    .image_memory_din(), 
    .image_memory_dout(pixel_value), 
    .image_memory_we(1'b0),
  
    .output_memory_clk(clk_100mhz), 
    .output_memory_addr(image_addr), 
    .output_memory_din(42), 
    .output_memory_dout(), 
    .output_memory_we(1'b1)
  );

  logic [11:0] pixel_value;
  logic [3:0] pixel_r, pixel_g, pixel_b;
  assign pixel_r = pixel_value[11:8];
  assign pixel_g = pixel_value[7:4];
  assign pixel_b = pixel_value[3:0];
  // logic [7:0] greyscale;
  // lol i can't just do this math here
  // FIX THIS:?
  // assign greyscale = pixel_r + pixel_g + pixel_b;
  // logic [$clog2(128*128)-1:0] write_address;
  // assign write_address = (image_addr==0) ? image_addr : image_addr - 1;

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      image_addr <= 0;
    end else begin
      if (image_addr < 128*128) begin
        image_addr <= image_addr + 1;
      end else begin
        image_addr <= 0;
      end 
    end
  end


  // BUILDING THE GAUSSIAN PYRAMID
  

  //two-port BRAM used to hold gaussian pyramid
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH(WIDTH*HEIGHT)) //there are WIDTH*HEIGHT entries for full frame
    gaussain_pyramid_buffer (
    .addra(hcount_rec + WIDTH*vcount_rec), //pixels are stored using this math
    .clka(clk_100mhz),
    .wea(data_valid_rec),
    .dina(pixel_data_rec),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(lookup_addr), // lookup pixel
    .dinb(16'b0),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(valid_addr),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(frame_buff_raw)
  );
  
endmodule // top_level


`default_nettype wire
