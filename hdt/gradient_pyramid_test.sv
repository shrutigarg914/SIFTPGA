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

    logic [13:0] pixel_addr;
    logic [7:0] rx_data;

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
    assign led[0] = full_image_received;
    assign led[1] = pyramid_done_latched;
    assign led[2] = gradient_done_latched;

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

      if (O1L1_gradient_done_latched && O1L2_gradient_done_latched && O1L3_gradient_done_latched
        && O2L1_gradient_done_latched && O2L2_gradient_done_latched && O2L3_gradient_done_latched
        && O3L1_gradient_done_latched && O3L2_gradient_done_latched && O3L3_gradient_done_latched) begin
        gradient_done_latched <= 1;
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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_grad_pixel_out;

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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L2_grad_pixel_out;

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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_grad_read_addr;
    logic [BIT_DEPTH-1:0] O1L3_grad_pixel_out;

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
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L1_grad_pixel_out;

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
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L2_grad_pixel_out;

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
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_grad_read_addr;
    logic [BIT_DEPTH-1:0] O2L3_grad_pixel_out;

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
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_grad_read_addr;
    logic [BIT_DEPTH-1:0] O3L1_grad_pixel_out;

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
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_grad_read_addr;
    logic [BIT_DEPTH-1:0] O3L2_grad_pixel_out;
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

    typedef enum {IDLE=0, 
                O1L1_x=1, 
                O1L1_y=2, 
                O1L2_x=3, 
                O1L2_y=4, 
                O1L3_x=5, 
                O1L3_y=6, 
                O2L1_x=7, 
                O2L1_y=8, 
                O2L2_x=9, 
                O2L2_y=10, 
                O2L3_x=11, 
                O2L3_y=12, 
                O3L1_x=13, 
                O3L1_y=14, 
                O3L2_x=15, 
                O3L2_y=16, 
                O3L3_x=17,
                O3L3_y=18
    } tx_state;

    tx_state state;
    tx_state state_prev;

    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            state <= IDLE;
        end else begin
            state_prev <= state;
            case (state)
                IDLE:
                    begin
                        if (btn_edge && gradient_done_latched) begin
                            state <= O1L1_x;
                        end
                    end
                O1L1_x:
                    begin
                        if (!tx_img_busy_O1L1_x && btn_edge) begin
                            state <= O1L1_y;
                        end
                        uart_txd <= O1L1_x_txd;
                    end
                O1L1_y:
                    begin
                        if (!tx_img_busy_O1L1_y && btn_edge) begin
                            state <= O1L2_x;
                        end
                        uart_txd <= O1L1_y_txd;
                    end
                O1L2_x:
                    begin
                        if (!tx_img_busy_O1L2_x && btn_edge) begin
                            state <= O1L2_y;
                        end
                        uart_txd <= O1L2_x_txd;
                    end
                O1L2_y:
                    begin
                        if (!tx_img_busy_O1L2_y && btn_edge) begin
                            state <= O1L3_x;
                        end
                        uart_txd <= O1L2_y_txd;
                    end
                O1L3_x:
                    begin
                        if (!tx_img_busy_O1L3_x && btn_edge) begin
                            state <= O1L3_y;
                        end
                        uart_txd <= O1L3_x_txd;
                    end
                O1L3_y:
                    begin
                        if (!tx_img_busy_O1L3_y && btn_edge) begin
                            state <= O2L1_x;
                        end
                        uart_txd <= O1L3_y_txd;
                    end
                O2L1_x:
                    begin
                        if (!tx_img_busy_O2L1_x && btn_edge) begin
                            state <= O2L1_y;
                        end
                        uart_txd <= O2L1_x_txd;
                    end
                O2L1_y:
                    begin
                        if (!tx_img_busy_O2L1_y && btn_edge) begin
                            state <= O2L2_x;
                        end
                        uart_txd <= O2L1_y_txd;
                    end
                O2L2_x:
                    begin
                        if (!tx_img_busy_O2L2_x && btn_edge) begin
                            state <= O2L2_y;
                        end
                        uart_txd <= O2L2_x_txd;
                    end
                O2L2_y:
                    begin
                        if (!tx_img_busy_O2L2_y && btn_edge) begin
                            state <= O2L3_x;
                        end
                        uart_txd <= O2L2_y_txd;
                    end
                O2L3_x:
                    begin
                        if (!tx_img_busy_O2L3_x && btn_edge) begin
                            state <= O2L3_y;
                        end
                        uart_txd <= O2L3_x_txd;
                    end
                O2L3_y:
                    begin
                        if (!tx_img_busy_O2L3_y && btn_edge) begin
                            state <= O3L1_x;
                        end
                        uart_txd <= O2L3_y_txd;
                    end
                O3L1_x:
                    begin
                        if (!tx_img_busy_O3L1_x && btn_edge) begin
                            state <= O3L1_y;
                        end
                        uart_txd <= O3L1_x_txd;
                    end
                O3L1_y:
                    begin
                        if (!tx_img_busy_O3L1_y && btn_edge) begin
                            state <= O3L2_x;
                        end
                        uart_txd <= O3L1_y_txd;
                    end
                O3L2_x:
                    begin
                        if (!tx_img_busy_O3L2_x && btn_edge) begin
                            state <= O3L2_y;
                        end
                        uart_txd <= O3L2_x_txd;
                    end
                O3L2_y:
                    begin
                        if (!tx_img_busy_O3L2_y && btn_edge) begin
                            state <= O3L3_x;
                        end
                        uart_txd <= O3L2_y_txd;
                    end
                O3L3_x:
                    begin
                        if (!tx_img_busy_O3L3_x && btn_edge) begin
                            state <= O3L3_y;
                        end
                        uart_txd <= O3L3_x_txd;
                    end
                O3L3_y:
                    begin
                        if (!tx_img_busy_O3L3_y && btn_edge) begin
                            state <= IDLE;
                        end
                        uart_txd <= O3L3_y_txd;
                    end
                default:
                    begin
                        state <= IDLE;
                    end
            endcase
        end
    end

    assign led[3] = (state == IDLE);
    assign led[4] = (state == O1L1_x || state == O1L1_y);
    assign led[5] = (state == O1L2_x || state == O1L2_y);
    assign led[6] = (state == O1L3_x || state == O1L3_y);
    assign led[7] = (state == O2L1_x || state == O2L1_y);
    assign led[8] = (state == O2L2_x || state == O2L2_y);
    assign led[9] = (state == O2L3_x || state == O2L3_y);
    assign led[10] = (state == O3L1_x || state == O3L1_y);
    assign led[11] = (state == O3L2_x || state == O3L2_y);
    assign led[12] = (state == O3L3_x || state == O3L3_y);


    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L1_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L1_x) && (state_prev != O1L1_x)),//full_image_received
      .tx(O1L1_x_txd),//uart_txd
      .data(o1_l1_x_pixel_out),
      .address(o1_l1_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L1_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L1_x;
    logic O1L1_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L1_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L1_y) && (state_prev != O1L1_y)),//full_image_received
      .tx(O1L1_y_txd),//uart_txd
      .data(o1_l1_y_pixel_out),
      .address(o1_l1_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L1_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L1_y;
    logic O1L1_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L2_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L2_x) && (state_prev != O1L2_x)),//full_image_received
      .tx(O1L2_x_txd),//uart_txd
      .data(o1_l2_x_pixel_out),
      .address(o1_l2_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L2_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L2_x;
    logic O1L2_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L2_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L2_y) && (state_prev != O1L2_y)),//full_image_received
      .tx(O1L2_y_txd),//uart_txd
      .data(o1_l2_y_pixel_out),
      .address(o1_l2_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L2_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L2_y;
    logic O1L2_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L3_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L3_x) && (state_prev != O1L3_x)),//full_image_received
      .tx(O1L3_x_txd),//uart_txd
      .data(o1_l3_x_pixel_out),
      .address(o1_l3_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L3_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L3_x;
    logic O1L3_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L3_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1L3_y) && (state_prev != O1L3_y)),//full_image_received
      .tx(O1L3_y_txd),//uart_txd
      .data(o1_l3_y_pixel_out),
      .address(o1_l3_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1L3_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1L3_y;
    logic O1L3_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L1_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L1_x) && (state_prev != O2L1_x)),//full_image_received
      .tx(O2L1_x_txd),//uart_txd
      .data(o2_l1_x_pixel_out),
      .address(o2_l1_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L1_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L1_x;
    logic O2L1_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L1_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L1_y) && (state_prev != O2L1_y)),//full_image_received
      .tx(O2L1_y_txd),//uart_txd
      .data(o2_l1_y_pixel_out),
      .address(o2_l1_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L1_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L1_y;
    logic O2L1_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L2_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L2_x) && (state_prev != O2L2_x)),//full_image_received
      .tx(O2L2_x_txd),//uart_txd
      .data(o2_l2_x_pixel_out),
      .address(o2_l2_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L2_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L2_x;
    logic O2L2_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L2_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L2_y) && (state_prev != O2L2_y)),//full_image_received
      .tx(O2L2_y_txd),//uart_txd
      .data(o2_l2_y_pixel_out),
      .address(o2_l2_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L2_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L2_y;
    logic O2L2_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L3_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L3_x) && (state_prev != O2L3_x)),//full_image_received
      .tx(O2L3_x_txd),//uart_txd
      .data(o2_l3_x_pixel_out),
      .address(o2_l3_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L3_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L3_x;
    logic O2L3_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L3_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L3_y) && (state_prev != O2L3_y)),//full_image_received
      .tx(O2L3_y_txd),//uart_txd
      .data(o2_l3_y_pixel_out),
      .address(o2_l3_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L3_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L3_y;
    logic O2L3_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L1_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L1_x) && (state_prev != O3L1_x)),//full_image_received
      .tx(O3L1_x_txd),//uart_txd
      .data(o3_l1_x_pixel_out),
      .address(o3_l1_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L1_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L1_x;
    logic O3L1_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L1_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L1_y) && (state_prev != O3L1_y)),//full_image_received
      .tx(O3L1_y_txd),//uart_txd
      .data(o3_l1_y_pixel_out),
      .address(o3_l1_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L1_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L1_y;
    logic O3L1_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L2_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L2_x) && (state_prev != O3L2_x)),//full_image_received
      .tx(O3L2_x_txd),//uart_txd
      .data(o3_l2_x_pixel_out),
      .address(o3_l2_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L2_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L2_x;
    logic O3L2_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L2_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L2_y) && (state_prev != O3L2_y)),//full_image_received
      .tx(O3L2_y_txd),//uart_txd
      .data(o3_l2_y_pixel_out),
      .address(o3_l2_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L2_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L2_y;
    logic O3L2_y_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L3_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L3_x) && (state_prev != O3L3_x)),//full_image_received
      .tx(O3L3_x_txd),//uart_txd
      .data(o3_l3_x_pixel_out),
      .address(o3_l3_x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L3_x) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L3_x;
    logic O3L3_x_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L3_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L3_y) && (state_prev != O3L3_y)),//full_image_received
      .tx(O3L3_y_txd),//uart_txd
      .data(o3_l3_y_pixel_out),
      .address(o3_l3_y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L3_y) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L3_y;
    logic O3L3_y_txd;

    
endmodule // top_level

`default_nettype wire
