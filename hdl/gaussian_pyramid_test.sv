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
    logic pyramid_done_latched;

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
    assign led[1] = pyramid_done;

    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pixel_addr <= 0;
        full_image_received <= 1'b0;
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
    o1_l1 (
        .addra(O1L1_write_addr),
        .clka(clk_100mhz),
        .wea(O1L1_write_valid),
        .dina(O1L1_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L1_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L1_write_addr;
    logic O1L1_write_valid;
    logic [BIT_DEPTH-1:0] O1L1_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L1_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l2 (
        .addra(O1L2_write_addr),
        .clka(clk_100mhz),
        .wea(O1L2_write_valid),
        .dina(O1L2_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L2_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L2_write_addr;
    logic O1L2_write_valid;
    logic [BIT_DEPTH-1:0] O1L2_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L2_read_addr;
    logic [BIT_DEPTH-1:0] O1L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l3 (
        .addra(O1L3_write_addr),
        .clka(clk_100mhz),
        .wea(O1L3_write_valid),
        .dina(O1L3_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1L3_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1L3_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L3_write_addr;
    logic O1L3_write_valid;
    logic [BIT_DEPTH-1:0] O1L3_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O1L3_read_addr;
    logic [BIT_DEPTH-1:0] O1L3_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l1 (
        .addra(O2L1_write_addr),
        .clka(clk_100mhz),
        .wea(O2L1_write_valid),
        .dina(O2L1_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L1_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_write_addr;
    logic O2L1_write_valid;
    logic [BIT_DEPTH-1:0] O2L1_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_read_addr;
    logic [BIT_DEPTH-1:0] O2L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l2 (
        .addra(O2L2_write_addr),
        .clka(clk_100mhz),
        .wea(O2L2_write_valid),
        .dina(O2L2_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L2_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_write_addr;
    logic O2L2_write_valid;
    logic [BIT_DEPTH-1:0] O2L2_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_read_addr;
    logic [BIT_DEPTH-1:0] O2L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l3 (
        .addra(O2L3_write_addr),
        .clka(clk_100mhz),
        .wea(O2L3_write_valid),
        .dina(O2L3_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O2L3_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O2L3_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_write_addr;
    logic O2L3_write_valid;
    logic [BIT_DEPTH-1:0] O2L3_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_read_addr;
    logic [BIT_DEPTH-1:0] O2L3_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l1 (
        .addra(O3L1_write_addr),
        .clka(clk_100mhz),
        .wea(O3L1_write_valid),
        .dina(O3L1_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L1_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L1_write_addr;
    logic O3L1_write_valid;
    logic [BIT_DEPTH-1:0] O3L1_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L1_read_addr;
    logic [BIT_DEPTH-1:0] O3L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l2 (
        .addra(O3L2_write_addr),
        .clka(clk_100mhz),
        .wea(O3L2_write_valid),
        .dina(O3L2_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L2_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L2_write_addr;
    logic O3L2_write_valid;
    logic [BIT_DEPTH-1:0] O3L2_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L2_read_addr;
    logic [BIT_DEPTH-1:0] O3L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l3 (
        .addra(O3L3_write_addr),
        .clka(clk_100mhz),
        .wea(O3L3_write_valid),
        .dina(O3L3_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O3L3_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O3L3_pixel_out)
    );
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L3_write_addr;
    logic O3L3_write_valid;
    logic [BIT_DEPTH-1:0] O3L3_pixel_out;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O3L3_read_addr;
    logic [BIT_DEPTH-1:0] O3L3_pixel_out;
    

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
                         .O1L1_pixel_out(O1L1_pixel_out), 
                         .O1L2_write_addr(O1L2_write_addr),
                         .O1L2_write_valid(O1L2_write_valid),
                         .O1L2_pixel_out(O1L2_pixel_out), 
                         .O1L3_write_addr(O1L3_write_addr),
                         .O1L3_write_valid(O1L3_write_valid),
                         .O1L3_pixel_out(O1L3_pixel_out), 
                         .O2L1_write_addr(O2L1_write_addr),
                         .O2L1_write_valid(O2L1_write_valid),
                         .O2L1_pixel_out(O2L1_pixel_out), 
                         .O2L2_write_addr(O2L2_write_addr),
                         .O2L2_write_valid(O2L2_write_valid),
                         .O2L2_pixel_out(O2L2_pixel_out), 
                         .O2L3_write_addr(O2L3_write_addr),
                         .O2L3_write_valid(O2L3_write_valid),
                         .O2L3_pixel_out(O2L3_pixel_out), 
                         .O3L1_write_addr(O3L1_write_addr),
                         .O3L1_write_valid(O3L1_write_valid),
                         .O3L1_pixel_out(O3L1_pixel_out), 
                         .O3L2_write_addr(O3L2_write_addr),
                         .O3L2_write_valid(O3L2_write_valid),
                         .O3L2_pixel_out(O3L2_pixel_out), 
                         .O3L3_write_addr(O3L3_write_addr),
                         .O3L3_write_valid(O3L3_write_valid),
                         .O3L3_pixel_out(O3L3_pixel_out), 
                         .start_in(start_pyramid),
                         .pyramid_done(pyramid_done));
    logic pyramid_done;

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

    send_img  tx_img (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready(btn_edge && pyramid_done_latched),//full_image_received
      .tx(uart_txd),//uart_txd
      .data(resized_stored_out),
      .address(read_resized_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy;
  
    assign led[13:2] = pixel_out;
    
endmodule // top_level

`default_nettype wire
