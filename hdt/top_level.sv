`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire [15:0] sw, //all 16 input slide switches
  input wire clk_100mhz,
  input wire uart_rxd,
  input wire [3:0] btn, //all four momentary button switches
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic uart_txd,
  output logic [15:0] led //16 green output LEDs (located right above switches)
  );
    //shut up those rgb LEDs (active high):
    assign rgb1= 0;
    assign rgb0 = 0;

    logic sys_rst;
    assign sys_rst = btn[0];

    parameter WIDTH = 64;
    parameter HEIGHT = 64;
    parameter BIT_DEPTH = 8;

    logic [$clog2(WIDTH*HEIGHT)-1:0] pixel_addr;
    logic [BIT_DEPTH-1:0] rx_data;

    logic valid_o;
    logic valid_o_edge;
    logic old_valid_o;
    logic start_pyramid;
    logic pyramid_done;
    logic pyramid_done_latched;
    logic gradient_done_latched;

    logic O1L1_gradient_done_latched;
    logic O1L2_gradient_done_latched;
    logic O1L3_gradient_done_latched;
    logic O2L1_gradient_done_latched;
    logic O2L2_gradient_done_latched;
    logic O2L3_gradient_done_latched;
    logic O3L1_gradient_done_latched;
    logic O3L2_gradient_done_latched;
    logic O3L3_gradient_done_latched;

    always_ff @(posedge clk_100mhz) begin
      if (valid_o==old_valid_o) begin
        valid_o_edge <= 1'b0;
      end else begin
        old_valid_o <= valid_o;
        valid_o_edge <= valid_o;
      end
    end

    // TODO: receive image sent over via python script
    uart_rx #(.CLOCKS_PER_BAUD(50))
      urx (
        .clk(clk_100mhz),
        .rx(uart_rxd),
        .data_o(rx_data),
        .valid_o(valid_o)
      );
    logic full_image_received;
    logic keypoints_done_latched;
    assign led[0] = full_image_received;
    assign led[1] = pyramid_done_latched;
    assign led[14] = keypoints_done_latched;
    logic gradient_done;

    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pixel_addr <= 0;
        full_image_received <= 1'b0;
        pyramid_done_latched <= 0;
        gradient_done_latched <= 0;
        O1L1_gradient_done_latched <= 0;
        O1L2_gradient_done_latched <= 0;
        O1L3_gradient_done_latched <= 0;
        O2L1_gradient_done_latched <= 0;
        O2L2_gradient_done_latched <= 0;
        O2L3_gradient_done_latched <= 0;
        O3L1_gradient_done_latched <= 0;
        O3L2_gradient_done_latched <= 0;
        O3L3_gradient_done_latched <= 0;
        start_pyramid <= 0;
      end
      else if (valid_o_edge) begin
        // pixel <= data_o; I'm assuming that data doesn't need to be held
        // for more than one cycle for writin to the BRAM
        pixel_addr <= pixel_addr + 1;
        if (pixel_addr== WIDTH*HEIGHT - 1) begin
          full_image_received <= 1'b1;
          start_pyramid <= 1'b1;
        end
      end

      if (start_pyramid) begin
        start_pyramid <= 0;
      end

      if (pyramid_done) begin
        pyramid_done_latched <= 1;
      end

      if (keypoints_done) begin
        keypoints_done_latched <= 1'b1;
      end

      if (O1L1_gradient_done_latched && O1L2_gradient_done_latched && O1L3_gradient_done_latched
        && O2L1_gradient_done_latched && O2L2_gradient_done_latched && O2L3_gradient_done_latched
        && O3L1_gradient_done_latched && O3L2_gradient_done_latched && O3L3_gradient_done_latched && ~gradient_done_latched) begin
        gradient_done_latched <= 1;
        gradient_done <= 1'b1;
      end

      if (gradient_done_latched) begin
        gradient_done <= 0;
      end

      if (O1L1_gradient_done) begin
        O1L1_gradient_done_latched <= 1;
      end
      if (O1L2_gradient_done) begin
        O1L2_gradient_done_latched <= 1;
      end
      if (O1L3_gradient_done) begin
        O1L3_gradient_done_latched <= 1;
      end
      if (O2L1_gradient_done) begin
        O2L1_gradient_done_latched <= 1;
      end
      if (O2L2_gradient_done) begin
        O2L2_gradient_done_latched <= 1;
      end
      if (O2L3_gradient_done) begin
        O2L3_gradient_done_latched <= 1;
      end
      if (O3L1_gradient_done) begin
        O3L1_gradient_done_latched <= 1;
      end
      if (O3L2_gradient_done) begin
        O3L2_gradient_done_latched <= 1;
      end
      if (O3L3_gradient_done) begin
        O3L3_gradient_done_latched <= 1;
      end
    end

    // the start image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(8), // we expect 8 bit greyscale images
        .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 16384 pixels total
        rx_img (
        .addra(pixel_addr),
        .clka(clk_100mhz),
        .wea(valid_o),
        .dina(rx_data),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(read_addr_valid),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(pixel_in)
    );

    logic [$clog2(WIDTH * HEIGHT)-1:0] read_addr;
    logic read_addr_valid;
    logic [BIT_DEPTH-1:0] pixel_in;

    // all of the pyramid BRAMs (oof)
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l1_DOG (
        .addra(O1L1_write_addr),
        .clka(clk_100mhz),
        .wea(O1L1_write_valid),
        .dina(O1L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L1_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L1_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l1_grad (
        .addra(O1L1_write_addr),
        .clka(clk_100mhz),
        .wea(O1L1_write_valid),
        .dina(O1L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L1_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L1_grad_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_write_addr;
    logic O1L1_write_valid;
    logic [BIT_DEPTH-1:0] O1L1_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_DOG_pixel_out;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l2_DOG (
        .addra(O1L2_write_addr),
        .clka(clk_100mhz),
        .wea(O1L2_write_valid),
        .dina(O1L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L2_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L2_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l2_grad (
        .addra(O1L2_write_addr),
        .clka(clk_100mhz),
        .wea(O1L2_write_valid),
        .dina(O1L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L2_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L2_grad_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_write_addr;
    logic O1L2_write_valid;
    logic [BIT_DEPTH-1:0] O1L2_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O1L2_DOG_pixel_out;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L2_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l3_DOG (
        .addra(O1L3_write_addr),
        .clka(clk_100mhz),
        .wea(O1L3_write_valid),
        .dina(O1L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L3_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L3_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l3_grad (
        .addra(O1L3_write_addr),
        .clka(clk_100mhz),
        .wea(O1L3_write_valid),
        .dina(O1L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L3_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L3_grad_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_write_addr;
    logic O1L3_write_valid;
    logic [BIT_DEPTH-1:0] O1L3_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O1L3_DOG_pixel_out;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L3_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l1_DOG (
        .addra(O2L1_write_addr),
        .clka(clk_100mhz),
        .wea(O2L1_write_valid),
        .dina(O2L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L1_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L1_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l1_grad (
        .addra(O2L1_write_addr),
        .clka(clk_100mhz),
        .wea(O2L1_write_valid),
        .dina(O2L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L1_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L1_grad_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_write_addr;
    logic O2L1_write_valid;
    logic [BIT_DEPTH-1:0] O2L1_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O2L1_DOG_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L1_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l2_DOG (
        .addra(O2L2_write_addr),
        .clka(clk_100mhz),
        .wea(O2L2_write_valid),
        .dina(O2L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L2_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L2_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l2_grad (
        .addra(O2L2_write_addr),
        .clka(clk_100mhz),
        .wea(O2L2_write_valid),
        .dina(O2L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L2_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L2_grad_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_write_addr;
    logic O2L2_write_valid;
    logic [BIT_DEPTH-1:0] O2L2_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O2L2_DOG_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L2_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l3_DOG (
        .addra(O2L3_write_addr),
        .clka(clk_100mhz),
        .wea(O2L3_write_valid),
        .dina(O2L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L3_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L3_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l3_grad (
        .addra(O2L3_write_addr),
        .clka(clk_100mhz),
        .wea(O2L3_write_valid),
        .dina(O2L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L3_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L3_grad_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_write_addr;
    logic O2L3_write_valid;
    logic [BIT_DEPTH-1:0] O2L3_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O2L3_DOG_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L3_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l1_DOG (
        .addra(O3L1_write_addr),
        .clka(clk_100mhz),
        .wea(O3L1_write_valid),
        .dina(O3L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L1_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L1_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l1_grad (
        .addra(O3L1_write_addr),
        .clka(clk_100mhz),
        .wea(O3L1_write_valid),
        .dina(O3L1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L1_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L1_grad_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_write_addr;
    logic O3L1_write_valid;
    logic [BIT_DEPTH-1:0] O3L1_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O3L1_DOG_pixel_out;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O3L1_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l2_DOG (
        .addra(O3L2_write_addr),
        .clka(clk_100mhz),
        .wea(O3L2_write_valid),
        .dina(O3L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L2_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L2_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l2_grad (
        .addra(O3L2_write_addr),
        .clka(clk_100mhz),
        .wea(O3L2_write_valid),
        .dina(O3L2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L2_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L2_grad_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_write_addr;
    logic O3L2_write_valid;
    logic [BIT_DEPTH-1:0] O3L2_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O3L2_DOG_pixel_out;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O3L2_grad_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l3_DOG (
        .addra(O3L3_write_addr),
        .clka(clk_100mhz),
        .wea(O3L3_write_valid),
        .dina(O3L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L3_DOG_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L3_DOG_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l3_grad (
        .addra(O3L3_write_addr),
        .clka(clk_100mhz),
        .wea(O3L3_write_valid),
        .dina(O3L3_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L3_grad_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L3_grad_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_write_addr;
    logic O3L3_write_valid;
    logic [BIT_DEPTH-1:0] O3L3_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_DOG_read_addr;
    logic [BIT_DEPTH-1:0] O3L3_DOG_pixel_out;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_grad_read_addr;
    logic [BIT_DEPTH-1:0] O3L3_grad_pixel_out;
    

    gaussian_pyramid #(
        .BIT_DEPTH(BIT_DEPTH),
        .TOP_WIDTH(WIDTH),
        .TOP_HEIGHT(HEIGHT))
    pyramid (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(read_addr),
                         .ext_read_addr_valid(read_addr_valid),
                         .ext_pixel_in(pixel_in),
                         .O1L1_write_addr(O1L1_write_addr),
                         .O1L1_write_valid(O1L1_write_valid),
                         .O1L1_pixel_out(O1L1_pixel_in), 
                         .O1L2_write_addr(O1L2_write_addr),
                         .O1L2_write_valid(O1L2_write_valid),
                         .O1L2_pixel_out(O1L2_pixel_in), 
                         .O1L3_write_addr(O1L3_write_addr),
                         .O1L3_write_valid(O1L3_write_valid),
                         .O1L3_pixel_out(O1L3_pixel_in), 
                         .O2L1_write_addr(O2L1_write_addr),
                         .O2L1_write_valid(O2L1_write_valid),
                         .O2L1_pixel_out(O2L1_pixel_in), 
                         .O2L2_write_addr(O2L2_write_addr),
                         .O2L2_write_valid(O2L2_write_valid),
                         .O2L2_pixel_out(O2L2_pixel_in), 
                         .O2L3_write_addr(O2L3_write_addr),
                         .O2L3_write_valid(O2L3_write_valid),
                         .O2L3_pixel_out(O2L3_pixel_in), 
                         .O3L1_write_addr(O3L1_write_addr),
                         .O3L1_write_valid(O3L1_write_valid),
                         .O3L1_pixel_out(O3L1_pixel_in), 
                         .O3L2_write_addr(O3L2_write_addr),
                         .O3L2_write_valid(O3L2_write_valid),
                         .O3L2_pixel_out(O3L2_pixel_in), 
                         .O3L3_write_addr(O3L3_write_addr),
                         .O3L3_write_valid(O3L3_write_valid),
                         .O3L3_pixel_out(O3L3_pixel_in), 
                         .start_in(start_pyramid),
                         .pyramid_done(pyramid_done));
    
    parameter DIMENSION = HEIGHT;
    // FOR OCTAVE 1
    parameter NUMBER_KEYPOINTS = 2000;

    logic [$clog2(NUMBER_KEYPOINTS)-1:0] key_write_addr, key_read_addr, desc_key_read_addr, tx_key_read_addr;
    logic key_wea;
    logic [(2*$clog2(DIMENSION)):0] keypoint_write, keypoint_read;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(2*$clog2(DIMENSION)+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(NUMBER_KEYPOINTS))
    keypoint (
        .addra(key_write_addr),
        .clka(clk_100mhz),
        .wea(key_wea),
        .dina(keypoint_write),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(key_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(keypoint_read)
    );

    // instantiating the find keypoints module. Needs a BRAM for keypoints
    find_keypoints #(.DIMENSION(DIMENSION), .NUMBER_KEYPOINTS(NUMBER_KEYPOINTS)) finder (
        .clk(clk_100mhz),
        .rst_in(sys_rst),
        .key_write_addr(key_write_addr),
        .key_wea(key_wea),
        .keypoint_out(keypoint_write),

        .O1L1_read_addr(O1L1_DOG_read_addr),
        .O1L1_data(O1L1_DOG_pixel_out),

        .O1L2_read_addr(O1L2_DOG_read_addr),
        .O1L2_data(O1L2_DOG_pixel_out),

        .O1L3_read_addr(O1L3_DOG_read_addr),
        .O1L3_data(O1L3_DOG_pixel_out),

        .O2L1_read_addr(O2L1_DOG_read_addr),
        .O2L1_data(O2L1_DOG_pixel_out),

        .O2L2_read_addr(O2L2_DOG_read_addr),
        .O2L2_data(O2L2_DOG_pixel_out),
      
        .O2L3_read_addr(O2L3_DOG_read_addr),
        .O2L3_data(O2L3_DOG_pixel_out),

        .O3L1_read_addr(O3L1_DOG_read_addr),
        .O3L1_data(O3L1_DOG_pixel_out),

        .O3L2_read_addr(O3L2_DOG_read_addr),
        .O3L2_data(O3L2_DOG_pixel_out),
      
        .O3L3_read_addr(O3L3_DOG_read_addr),
        .O3L3_data(O3L3_DOG_pixel_out),
        // start and done signals
        .start(pyramid_done),
        .keypoints_done(keypoints_done)

    );

    logic keypoints_done;

    logic O1L1_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT))
    o1_l1_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O1L1_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O1L1_grad_pixel_out),
                         .x_write_addr(o1_l1_x_write_addr),
                         .x_write_valid(o1_l1_x_write_valid),
                         .x_pixel_out(o1_l1_x_pixel_in), 
                         .y_write_addr(o1_l1_y_write_addr),
                         .y_write_valid(o1_l1_y_write_valid),
                         .y_pixel_out(o1_l1_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O1L1_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l1_x_grad (
        .addra(o1_l1_x_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l1_x_write_valid),
        .dina(o1_l1_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l1_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l1_x_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l1_x_write_addr;
    logic o1_l1_x_write_valid;
    logic [BIT_DEPTH-1:0] o1_l1_x_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l1_x_read_addr;
    logic [BIT_DEPTH-1:0] o1_l1_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l1_y_grad (
        .addra(o1_l1_y_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l1_y_write_valid),
        .dina(o1_l1_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l1_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l1_y_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l1_y_write_addr;
    logic o1_l1_y_write_valid;
    logic [BIT_DEPTH-1:0] o1_l1_y_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l1_y_read_addr;
    logic [BIT_DEPTH-1:0] o1_l1_y_pixel_out;

    logic O1L2_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT))
    o1_l2_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O1L2_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O1L2_grad_pixel_out),
                         .x_write_addr(o1_l2_x_write_addr),
                         .x_write_valid(o1_l2_x_write_valid),
                         .x_pixel_out(o1_l2_x_pixel_in), 
                         .y_write_addr(o1_l2_y_write_addr),
                         .y_write_valid(o1_l2_y_write_valid),
                         .y_pixel_out(o1_l2_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O1L2_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l2_x_grad (
        .addra(o1_l2_x_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l2_x_write_valid),
        .dina(o1_l2_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l2_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l2_x_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l2_x_write_addr;
    logic o1_l2_x_write_valid;
    logic [BIT_DEPTH-1:0] o1_l2_x_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l2_x_read_addr;
    logic [BIT_DEPTH-1:0] o1_l2_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l2_y_grad (
        .addra(o1_l2_y_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l2_y_write_valid),
        .dina(o1_l2_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l2_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l2_y_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l2_y_write_addr;
    logic o1_l2_y_write_valid;
    logic [BIT_DEPTH-1:0] o1_l2_y_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l2_y_read_addr;
    logic [BIT_DEPTH-1:0] o1_l2_y_pixel_out;

    logic O1L3_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT))
    o1_l3_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O1L3_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O1L3_grad_pixel_out),
                         .x_write_addr(o1_l3_x_write_addr),
                         .x_write_valid(o1_l3_x_write_valid),
                         .x_pixel_out(o1_l3_x_pixel_in), 
                         .y_write_addr(o1_l3_y_write_addr),
                         .y_write_valid(o1_l3_y_write_valid),
                         .y_pixel_out(o1_l3_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O1L3_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l3_x_grad (
        .addra(o1_l3_x_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l3_x_write_valid),
        .dina(o1_l3_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l3_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l3_x_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l3_x_write_addr;
    logic o1_l3_x_write_valid;
    logic [BIT_DEPTH-1:0] o1_l3_x_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l3_x_read_addr;
    logic [BIT_DEPTH-1:0] o1_l3_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    o1_l3_y_grad (
        .addra(o1_l3_y_write_addr),
        .clka(clk_100mhz),
        .wea(o1_l3_y_write_valid),
        .dina(o1_l3_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o1_l3_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o1_l3_y_pixel_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l3_y_write_addr;
    logic o1_l3_y_write_valid;
    logic [BIT_DEPTH-1:0] o1_l3_y_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] o1_l3_y_read_addr;
    logic [BIT_DEPTH-1:0] o1_l3_y_pixel_out;

    logic O2L1_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/2),
        .HEIGHT(HEIGHT/2))
    o2_l1_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O2L1_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O2L1_grad_pixel_out),
                         .x_write_addr(o2_l1_x_write_addr),
                         .x_write_valid(o2_l1_x_write_valid),
                         .x_pixel_out(o2_l1_x_pixel_in), 
                         .y_write_addr(o2_l1_y_write_addr),
                         .y_write_valid(o2_l1_y_write_valid),
                         .y_pixel_out(o2_l1_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O2L1_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l1_x_grad (
        .addra(o2_l1_x_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l1_x_write_valid),
        .dina(o2_l1_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l1_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l1_x_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l1_x_write_addr;
    logic o2_l1_x_write_valid;
    logic [BIT_DEPTH-1:0] o2_l1_x_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l1_x_read_addr;
    logic [BIT_DEPTH-1:0] o2_l1_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l1_y_grad (
        .addra(o2_l1_y_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l1_y_write_valid),
        .dina(o2_l1_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l1_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l1_y_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l1_y_write_addr;
    logic o2_l1_y_write_valid;
    logic [BIT_DEPTH-1:0] o2_l1_y_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l1_y_read_addr;
    logic [BIT_DEPTH-1:0] o2_l1_y_pixel_out;

    logic O2L2_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/2),
        .HEIGHT(HEIGHT/2))
    o2_l2_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O2L2_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O2L2_grad_pixel_out),
                         .x_write_addr(o2_l2_x_write_addr),
                         .x_write_valid(o2_l2_x_write_valid),
                         .x_pixel_out(o2_l2_x_pixel_in), 
                         .y_write_addr(o2_l2_y_write_addr),
                         .y_write_valid(o2_l2_y_write_valid),
                         .y_pixel_out(o2_l2_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O2L2_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l2_x_grad (
        .addra(o2_l2_x_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l2_x_write_valid),
        .dina(o2_l2_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l2_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l2_x_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l2_x_write_addr;
    logic o2_l2_x_write_valid;
    logic [BIT_DEPTH-1:0] o2_l2_x_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l2_x_read_addr;
    logic [BIT_DEPTH-1:0] o2_l2_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l2_y_grad (
        .addra(o2_l2_y_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l2_y_write_valid),
        .dina(o2_l2_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l2_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l2_y_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l2_y_write_addr;
    logic o2_l2_y_write_valid;
    logic [BIT_DEPTH-1:0] o2_l2_y_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l2_y_read_addr;
    logic [BIT_DEPTH-1:0] o2_l2_y_pixel_out;

    logic O2L3_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/2),
        .HEIGHT(HEIGHT/2))
    o2_l3_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O2L3_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O2L3_grad_pixel_out),
                         .x_write_addr(o2_l3_x_write_addr),
                         .x_write_valid(o2_l3_x_write_valid),
                         .x_pixel_out(o2_l3_x_pixel_in), 
                         .y_write_addr(o2_l3_y_write_addr),
                         .y_write_valid(o2_l3_y_write_valid),
                         .y_pixel_out(o2_l3_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O2L3_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l3_x_grad (
        .addra(o2_l3_x_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l3_x_write_valid),
        .dina(o2_l3_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l3_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l3_x_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l3_x_write_addr;
    logic o2_l3_x_write_valid;
    logic [BIT_DEPTH-1:0] o2_l3_x_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l3_x_read_addr;
    logic [BIT_DEPTH-1:0] o2_l3_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/2*HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
    o2_l3_y_grad (
        .addra(o2_l3_y_write_addr),
        .clka(clk_100mhz),
        .wea(o2_l3_y_write_valid),
        .dina(o2_l3_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o2_l3_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o2_l3_y_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l3_y_write_addr;
    logic o2_l3_y_write_valid;
    logic [BIT_DEPTH-1:0] o2_l3_y_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] o2_l3_y_read_addr;
    logic [BIT_DEPTH-1:0] o2_l3_y_pixel_out;

    logic O3L1_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/4),
        .HEIGHT(HEIGHT/4))
    o3_l1_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O3L1_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O3L1_grad_pixel_out),
                         .x_write_addr(o3_l1_x_write_addr),
                         .x_write_valid(o3_l1_x_write_valid),
                         .x_pixel_out(o3_l1_x_pixel_in), 
                         .y_write_addr(o3_l1_y_write_addr),
                         .y_write_valid(o3_l1_y_write_valid),
                         .y_pixel_out(o3_l1_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O3L1_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
    o3_l1_x_grad (
        .addra(o3_l1_x_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l1_x_write_valid),
        .dina(o3_l1_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l1_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l1_x_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l1_x_write_addr;
    logic o3_l1_x_write_valid;
    logic [BIT_DEPTH-1:0] o3_l1_x_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l1_x_read_addr;
    logic [BIT_DEPTH-1:0] o3_l1_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
    o3_l1_y_grad (
        .addra(o3_l1_y_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l1_y_write_valid),
        .dina(o3_l1_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l1_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l1_y_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l1_y_write_addr;
    logic o3_l1_y_write_valid;
    logic [BIT_DEPTH-1:0] o3_l1_y_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l1_y_read_addr;
    logic [BIT_DEPTH-1:0] o3_l1_y_pixel_out;

    logic O3L2_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/4),
        .HEIGHT(HEIGHT/4))
    o3_l2_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O3L2_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O3L2_grad_pixel_out),
                         .x_write_addr(o3_l2_x_write_addr),
                         .x_write_valid(o3_l2_x_write_valid),
                         .x_pixel_out(o3_l2_x_pixel_in), 
                         .y_write_addr(o3_l2_y_write_addr),
                         .y_write_valid(o3_l2_y_write_valid),
                         .y_pixel_out(o3_l2_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O3L2_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
    o3_l2_x_grad (
        .addra(o3_l2_x_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l2_x_write_valid),
        .dina(o3_l2_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l2_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l2_x_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l2_x_write_addr;
    logic o3_l2_x_write_valid;
    logic [BIT_DEPTH-1:0] o3_l2_x_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l2_x_read_addr;
    logic [BIT_DEPTH-1:0] o3_l2_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
    o3_l2_y_grad (
        .addra(o3_l2_y_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l2_y_write_valid),
        .dina(o3_l2_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l2_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l2_y_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l2_y_write_addr;
    logic o3_l2_y_write_valid;
    logic [BIT_DEPTH-1:0] o3_l2_y_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l2_y_read_addr;
    logic [BIT_DEPTH-1:0] o3_l2_y_pixel_out;

    logic O3L3_gradient_done;
    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH/4),
        .HEIGHT(HEIGHT/4))
    o3_l3_gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(O3L3_grad_read_addr),
                         .ext_read_addr_valid(),
                         .ext_pixel_in(O3L3_grad_pixel_out),
                         .x_write_addr(o3_l3_x_write_addr),
                         .x_write_valid(o3_l3_x_write_valid),
                         .x_pixel_out(o3_l3_x_pixel_in), 
                         .y_write_addr(o3_l3_y_write_addr),
                         .y_write_valid(o3_l3_y_write_valid),
                         .y_pixel_out(o3_l3_y_pixel_in), 
                         .start_in(pyramid_done),
                         .gradient_done(O3L3_gradient_done),
                         .state_num());
    
    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 16*16 image
    o3_l3_x_grad (
        .addra(o3_l3_x_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l3_x_write_valid),
        .dina(o3_l3_x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l3_x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l3_x_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l3_x_write_addr;
    logic o3_l3_x_write_valid;
    logic [BIT_DEPTH-1:0] o3_l3_x_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l3_x_read_addr;
    logic [BIT_DEPTH-1:0] o3_l3_x_pixel_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH/4*HEIGHT/4)) //we expect a 16*16 image
    o3_l3_y_grad (
        .addra(o3_l3_y_write_addr),
        .clka(clk_100mhz),
        .wea(o3_l3_y_write_valid),
        .dina(o3_l3_y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(o3_l3_y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(o3_l3_y_pixel_out)
    );
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] o3_l3_y_write_addr;
    logic o3_l3_y_write_valid;
    logic [BIT_DEPTH-1:0] o3_l3_y_pixel_in;
    logic [$clog2(WIDTH/4* HEIGHT/4)-1:0] o3_l3_y_read_addr;
    logic [BIT_DEPTH-1:0] o3_l3_y_pixel_out;


    // the descriptor BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(($clog2(PATCH_SIZE/2 * PATCH_SIZE/2)+ 1)*8), // 3 bits for 8 bins
    .RAM_DEPTH(NUMBER_KEYPOINTS*4))
    descriptors (
        .addra(desc_write_addr),
        .clka(clk_100mhz),
        .wea(desc_write_valid),
        .dina(descriptor_write),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(desc_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(descriptor_read)
    );

    parameter PATCH_SIZE = 4;
    logic [$clog2(NUMBER_KEYPOINTS*4)-1:0] desc_write_addr;
    logic desc_write_valid;
    logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2)+ 1)*8-1:0] descriptor_write;
    logic [$clog2(NUMBER_KEYPOINTS*4)-1:0] desc_read_addr;
    logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2)+ 1)*8-1:0] descriptor_read;


    generate_descriptors #(.NUMBER_DESCRIPTORS(NUMBER_KEYPOINTS*4)) generator (
    .clk(clk_100mhz),
    .rst_in(sys_rst),
    // For  descriptors
    .desc_write_addr(desc_write_addr),
    .desc_wea(desc_write_valid),
    .desc_out(descriptor_write),

    .key_read_addr(desc_key_read_addr),
    .keypoint_read(keypoint_read),

    .O1L1_x_grad(o1_l1_x_pixel_out),
    .O1L1_y_grad(o1_l1_y_pixel_out),
    .O1L1_x_address(o1_l1_x_read_addr),
    .O1L1_y_address(o1_l1_y_read_addr),
    
    .O1L2_x_grad(o1_l2_x_pixel_out),
    .O1L2_y_grad(o1_l2_y_pixel_out),
    .O1L2_x_address(o1_l2_x_read_addr),
    .O1L2_y_address(o1_l2_y_read_addr),

    .O2L1_x_grad(o2_l1_x_pixel_out),
    .O2L1_y_grad(o2_l1_y_pixel_out),
    .O2L1_x_address(o2_l1_x_read_addr),
    .O2L1_y_address(o2_l1_y_read_addr),

    .O2L2_x_grad(o2_l2_x_pixel_out),
    .O2L2_y_grad(o2_l2_y_pixel_out),
    .O2L2_x_address(o2_l2_x_read_addr),
    .O2L2_y_address(o2_l2_y_read_addr),

    .O3L1_x_grad(o3_l1_x_pixel_out),
    .O3L1_y_grad(o3_l1_y_pixel_out),
    .O3L1_x_address(o3_l1_x_read_addr),
    .O3L1_y_address(o3_l1_y_read_addr),

    .O3L2_x_grad(o3_l2_x_pixel_out),
    .O3L2_y_grad(o3_l2_y_pixel_out),
    .O3L2_x_address(o3_l2_x_read_addr),
    .O3L2_y_address(o3_l2_y_read_addr),

    .start((keypoints_done_latched && gradient_done) || (gradient_done_latched && keypoints_done)),
    .descriptors_done(descriptors_done),
    .octave_state_num(desc_octave),
    .generic_state_num(desc_state)
  );
    logic [3:0] desc_state;
    assign led[8:5] = desc_state; 
    logic [1:0] desc_octave;
    assign led[4:3] = desc_octave;
    logic descriptors_done, descriptors_done_latched;
    
    always_comb begin
        if (descriptors_done_latched) begin
            key_read_addr = tx_key_read_addr;
        end else begin
            key_read_addr = desc_key_read_addr;
        end
    end
    logic descriptor_was_started;

    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            descriptors_done_latched <= 0;
            descriptor_was_started <= 0;
        end else begin
            if (descriptors_done) begin
                descriptors_done_latched <= 1'b1;
            end
            if ((keypoints_done_latched && gradient_done) || (gradient_done_latched && keypoints_done)) begin
                descriptor_was_started <= 1'b1;
            end else begin
                descriptor_was_started <= 1'b0;
            end
            // if (desc_oct)
        end
    end

    // when btn[1] pressed if pyramid is done, send what's stored in the pyramid BRAMs to the laptop
    // button press detected by 
    logic btn_edge;

    //rest of the logic here
    logic start_i;
    logic done_o;
    logic [7:0] data_i;
    logic btn_pulse;
    logic old_btn_pulse;
    debouncer btn1_db(.clk_in(clk_100mhz),
                    .rst_in(sys_rst),
                    .dirty_in(btn[1]),
                    .clean_out(btn_pulse));
 
    /* this should go high for one cycle on the
    * rising edge of the (debounced) button output
    */ 
    /* TODO: write your edge detector for part 1 of the
    * lab here!
    */
    always_ff @(posedge clk_100mhz) begin
      if (btn_pulse==old_btn_pulse) begin
        btn_edge <= 1'b0;
      end else begin
        old_btn_pulse <= btn_pulse;
        btn_edge <= btn_pulse;
      end
    end

    typedef enum {IDLE=0, KEY=1, DESC=2} tx_state;
    tx_state state;
    tx_state state_prev;

    assign led[15] = descriptor_was_started;
    
    // to send each image in the pyramid down tx
    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            state <= IDLE;
        end else begin
            state_prev <= state;
            case (state)
                IDLE:
                    begin
                        if (btn_edge && descriptors_done_latched) begin
                            state <= KEY;
                        end
                    end
                KEY:
                    begin
                        if (!tx_busy_key && btn_edge) begin
                            state <= DESC;
                        end
                        uart_txd <= key_txd;
                    end
                DESC:
                    begin
                        if (!tx_busy_desc && btn_edge) begin
                            state <= DESC;
                        end
                        uart_txd <= desc_txd;
                    end
                default:
                    begin
                        state <= IDLE;
                    end
            endcase
        end
    end

    assign led[2] = (state == IDLE);
    // assign led[3] = (state == O1L1);
    // assign led[4] = (state == O1L2);
    // assign led[5] = (state == O1L3);
    // assign led[6] = (state == O2L1);
    // assign led[7] = (state == O2L2);
    // assign led[8] = (state == O2L3);
    assign led[9] = gradient_done_latched;
    assign led[10] = descriptors_done_latched;
    // assign led[3] = (state == DESC);
    // assign led[4] = (state == KEY);


    send_keypoints #(.BRAM_LENGTH(2000)) tx_keypoint (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == KEY) && (state_prev != KEY)),//full_image_received
      .tx(key_txd),//uart_txd
      .data(keypoint_read),
      .address(tx_key_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_busy_key) //or we could do img_sent whichever makes more sense
    );
    logic tx_busy_key;
    logic key_txd;

    send_descriptors #(.BRAM_LENGTH(1000)) tx_descriptors (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == DESC) && (state_prev != DESC)),//full_image_received
      .tx(desc_txd),//uart_txd
      .data(descriptor_read),
      .address(desc_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_busy_desc) //or we could do img_sent whichever makes more sense
    );
    logic tx_busy_desc;
    logic desc_txd;

    
endmodule // top_level

`default_nettype wire
