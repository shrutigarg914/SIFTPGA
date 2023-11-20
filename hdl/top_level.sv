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
  // Locating pyramid address STAGE 3
  parameter WIDTH = 128;
  parameter HEIGHT = 128;
  parameter BIT_DEPTH = 8;
  logic [7:0] center_addr_x;
  logic [7:0] center_addr_y;
  logic [7:0] lookup_addr;
  logic lookup_valid;
  logic [2:0] pyramid_level; // layer in gaussian pyramid
  logic [2:0] blur_level; // horizontal location of current image in gaussian pyramid
  logic pyramid_done; // if we are done building the pyramid, stop increasing above addresses and stop writing to BRAM
  logic [7:0] resize_in;
  logic pyramid_location_ready;

  // TEMP
  logic [BIT_DEPTH:0] pixel_in;
  logic data_valid_rec;

  logic [BIT_DEPTH:0] pixel_out_0; // pixel out from original image
  //two-port BRAM used to hold image from uart.
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH(WIDTH*HEIGHT)) //there are WIDTH*HEIGHT entries for full frame
    frame_buffer (
    .addra(image_addr), // TODO: TEMP
    .clka(clk_100mhz),
    .wea(data_valid_rec), // TODO: TEMP
    .dina(pixel_in), // TODO: TEMP
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(lookup_addr), // lookup pixel
    .dinb(16'b0),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(lookup_valid),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(pixel_out_0)
  );

  logic resize1_data_valid_in;
  logic [BIT_DEPTH:0] pixel_out_1; // pixel out from first downsized image
  //two-port BRAM used to hold the first downsized images
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH((WIDTH / 2) * (HEIGHT / 2)))
    resize_buffer (
    .addra(center_addr_x + center_addr_y * HEIGHT / 2),
    .clka(clk_100mhz),
    .wea(resize1_data_valid_in),
    .dina(resize_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(lookup_addr), // lookup pixel
    .dinb(16'b0),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(lookup_valid),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(pixel_out_1)
  );

  logic resize2_data_valid_in;
  logic [BIT_DEPTH:0] pixel_out_2; // pixel out from second downsized image
  //two-port BRAM used to hold the first downsized images
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH((WIDTH / 2) * (HEIGHT / 2)))
    resize_buffer (
    .addra(center_addr_x + center_addr_y * HEIGHT / 2),
    .clka(clk_100mhz),
    .wea(resize2_data_valid_in),
    .dina(resize_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(lookup_addr), // lookup pixel
    .dinb(16'b0),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(lookup_valid),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(pixel_out_2)
  );

  logic resize3_data_valid_in;
  logic [BIT_DEPTH:0] pixel_out_3; // pixel out from third downsized image
  //two-port BRAM used to hold the first downsized images
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
    .RAM_DEPTH((WIDTH / 2) * (HEIGHT / 2)))
    resize_buffer (
    .addra(center_addr_x + center_addr_y * HEIGHT / 2),
    .clka(clk_100mhz),
    .wea(resize3_data_valid_in),
    .dina(resize_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(lookup_addr), // lookup pixel
    .dinb(16'b0),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(lookup_valid),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(pixel_out_3)
  );

  // Gaussian Blur STAGE 2
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

  // Gathering kernel data STAGE 1
  logic kernel_data_ready;
  logic [1:0] kernel_x;
  logic [1:0] kernel_y;

  logic kernel_x_intermediate;
  logic kernel_y_intermediate;
  logic height_intermediate;

  // get lookup address
  always_comb begin
    // saturate edges
    if (center_addr_x == 0 && kernel_x == 0) begin
      kernel_x_intermediate = center_addr_x;
    end
    if (center_addr_x == WIDTH-1 && kernel_x == 2) begin
      kernel_x_intermediate = center_addr_x;
    end
    if (center_addr_y == 0 && kernel_y == 0) begin
      kernel_y_intermediate = center_addr_y;
    end
    if (center_addr_y == WIDTH-1 && kernel_y == 2) begin
      kernel_y_intermediate = center_addr_y;
    end

    // Get image height at current octave
    case (pyramid_level)
      0: height_intermediate = HEIGHT;
      1: height_intermediate = HEIGHT / 2;
      2: height_intermediate = HEIGHT / 4;
      3: height_intermediate = HEIGHT / 8;
    endcase

    lookup_addr = kernel_x_intermediate + kernel_y_intermediate * height_intermediate;
  end

  // TODO: Figure out how to signal collecting kernel pixels from BRAM, to waiting for blur module + storing result, to increasing center addr
  // Notes: Need to read 9 pixels, one at a time from BRAM (which takes 2 cycles each) to gather all kernel data
  // Blur module takes 4 cycles
  // Increasing the center address may take up to 4 cycles
  // Up to some amount of time for image resizing on each inc pyramid level
  // In total, should pipeline this so that each pixel of the pyramid takes 9*2=18 cycles? HOW???

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      center_addr_x <= 0;
      center_addr_y <= 0;
      blur_level <= 0;
      pyramid_level <= 0;
      pyramid_done <= 0;
    end else begin
      // Collect Kernel Pixels
      if (pyramid_location_ready) begin // TODO: Add check that uart collection BRAM is ready

        // read out of right BRAM
        case (pyramid_level)
          0:
            
          1:

          2:

          3:
        endcase
      end

      // Start blur module
      if (kernel_data_ready) begin
        blur_data_valid_in <= 1;
      end

      // TODO: SAVE OUTPUT TO PYRAMID

      // Increase center addr
      if (blur_data_valid_out) begin
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
  end

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
