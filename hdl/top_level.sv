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
  parameter WIDTH = 128;
  parameter HEIGHT = 128;
  parameter BIT_DEPTH = 8;
  logic [7:0] center_addr_x;
  logic [7:0] center_addr_y;
  logic [7:0] lookup_addr;
  logic [2:0] pyramid_level; // layer in gaussian pyramid
  logic [2:0] blur_level; // horizontal location of current image in gaussian pyramid
  logic pyramid_done; // if we are done building the pyramid, stop increasing above addresses and stop writing to BRAM

  //two-port BRAM used to hold image from uart.
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH(WIDTH*HEIGHT)) //there are WIDTH*HEIGHT entries for full frame
    frame_buffer (
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

  parameter BIT_DEPTH = 8;
  logic[BIT_DEPTH*3-1:0] row1;
  logic[BIT_DEPTH*3-1:0] row2;
  logic[BIT_DEPTH*3-1:0] row3;
  logic blur_data_valid_in;
  logic blur_out;
  logic blur_data_valid_out;
  logic blur_busy;

  gaussian #(
      .WIDTH(BIT_DEPTH))
    blur (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .r0_data_in(row1),
    .r1_data_in(row2),
    .r2_data_in(row3),
    .data_valid_in(blur_data_valid_in),
    .data_out(blur_out),
    .data_valid_out(blur_data_valid_out),
    .error_out(),
    .busy_out()
  );

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      center_addr_x <= 0;
      center_addr_y <= 0;
      blur_level <= 0;
      pyramid_level <= 0;
      pyramid_done <= 0;
    end else begin
      if (center_addr_x < WIDTH) begin // Inc X
        center_addr_x <= center_addr_x + 1;
      end else begin
        center_addr_x <= 0;
        if (center_addr_y < HEIGHT) begin // Inc Y
          center_addr_y <= center_addr_y + 1;
        end else begin
          center_addr_y <= 0;
          if (blur_level < 4) begin // Inc blur level
            blur_level <= blur_level + 1;
          end else begin
            blur_level <= 0;
              if (pyramid_level < 4) begin  // Inc pyramid level
                pyramid_level <= pyramid_level + 1;
              end else begin
                pyramid_level <= 0;
                pyramid_done <= 1;
          end
          end
        end
      end
    end
  end

  //two-port BRAM used to hold gaussian pyramid
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH(WIDTH*HEIGHT)) //there are WIDTH*HEIGHT entries for full frame
    frame_buffer (
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
