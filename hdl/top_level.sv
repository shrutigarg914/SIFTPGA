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
    // assign led[13] = dog_one_done;
    assign led[14] = keypoints_done_latched;

    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pixel_addr <= 0;
        full_image_received <= 1'b0;
        pyramid_done_latched <= 0;
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
        .dina(O1L1_pixel_in),
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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_write_addr;
    logic O1L1_write_valid;
    logic [BIT_DEPTH-1:0] O1L1_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l2 (
        .addra(O1L2_write_addr),
        .clka(clk_100mhz),
        .wea(O1L2_write_valid),
        .dina(O1L2_pixel_in),
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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_write_addr;
    logic O1L2_write_valid;
    logic [BIT_DEPTH-1:0] O1L2_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_read_addr;
    logic [BIT_DEPTH-1:0] O1L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH*HEIGHT))
    o1_l3 (
        .addra(O1L3_write_addr),
        .clka(clk_100mhz),
        .wea(O1L3_write_valid),
        .dina(O1L3_pixel_in),
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
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_write_addr;
    logic O1L3_write_valid;
    logic [BIT_DEPTH-1:0] O1L3_pixel_in;
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_read_addr;
    logic [BIT_DEPTH-1:0] O1L3_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l1 (
        .addra(O2L1_write_addr),
        .clka(clk_100mhz),
        .wea(O2L1_write_valid),
        .dina(O2L1_pixel_in),
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
    logic [BIT_DEPTH-1:0] O2L1_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_read_addr;
    logic [BIT_DEPTH-1:0] O2L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l2 (
        .addra(O2L2_write_addr),
        .clka(clk_100mhz),
        .wea(O2L2_write_valid),
        .dina(O2L2_pixel_in),
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
    logic [BIT_DEPTH-1:0] O2L2_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_read_addr;
    logic [BIT_DEPTH-1:0] O2L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/2*HEIGHT/2))
    o2_l3 (
        .addra(O2L3_write_addr),
        .clka(clk_100mhz),
        .wea(O2L3_write_valid),
        .dina(O2L3_pixel_in),
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
    logic [BIT_DEPTH-1:0] O2L3_pixel_in;
    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_read_addr;
    logic [BIT_DEPTH-1:0] O2L3_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l1 (
        .addra(O3L1_write_addr),
        .clka(clk_100mhz),
        .wea(O3L1_write_valid),
        .dina(O3L1_pixel_in),
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
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_write_addr;
    logic O3L1_write_valid;
    logic [BIT_DEPTH-1:0] O3L1_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_read_addr;
    logic [BIT_DEPTH-1:0] O3L1_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l2 (
        .addra(O3L2_write_addr),
        .clka(clk_100mhz),
        .wea(O3L2_write_valid),
        .dina(O3L2_pixel_in),
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
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_write_addr;
    logic O3L2_write_valid;
    logic [BIT_DEPTH-1:0] O3L2_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_read_addr;
    logic [BIT_DEPTH-1:0] O3L2_pixel_out;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(WIDTH/4*HEIGHT/4))
    o3_l3 (
        .addra(O3L3_write_addr),
        .clka(clk_100mhz),
        .wea(O3L3_write_valid),
        .dina(O3L3_pixel_in),
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
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_write_addr;
    logic O3L3_write_valid;
    logic [BIT_DEPTH-1:0] O3L3_pixel_in;
    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_read_addr;
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
    logic [$clog2(HEIGHT * WIDTH)-1:0] O1key_write_addr, O1key_read_addr;
    logic O1key_wea;
    logic [(2*$clog2(DIMENSION)):0] O1_keypoint_write, O1_keypoint_read;

    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(2*$clog2(DIMENSION)+1), // we expect 8 bit greyscale images
    .RAM_DEPTH(1000))
    o1_keypt (
        .addra(O1key_write_addr),
        .clka(clk_100mhz),
        .wea(O1key_wea),
        .dina(O1_keypoint_write),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(O1key_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(O1_keypoint_read)
    );

    logic found_zero;
    assign led[13] = found_zero;
    // instantiating the find keypoints module. Needs a BRAM for keypoints
    find_keypoints #(.DIMENSION(DIMENSION)) finder (
        .clk(clk_100mhz),
        .rst_in(sys_rst),
        .O1key_write_addr(O1key_write_addr),
        .O1key_wea(O1key_wea),
        .O1_keypoint_out(O1_keypoint_write),

        .O1L1_read_addr(O1L1_read_addr),
        .O1L1_data(O1L1_pixel_out),

        .O1L2_read_addr(O1L2_read_addr),
        .O1L2_data(O1L2_pixel_out),

        .O1L3_read_addr(O1L2_read_addr),
        .O1L3_data(O1L3_pixel_out),
        .found_zero(found_zero),

        // start and done signals
        .start(pyramid_done),
        .keypoints_done(keypoints_done),

        .O1_DOG_L2L3_done(dog_one_done)
    );

    logic keypoints_done, dog_one_done;

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

    typedef enum {IDLE=0, O1L1=1, O1L2=2, O1L3=3, O2L1=4, O2L2=5, O2L3=6, O3L1=7, O3L2=8, O3L3=9, O1KEY=10} tx_state;
    tx_state state;
    tx_state state_prev;

    assign led[15] = 1;
    
    // to send each image in the pyramid down tx
    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            state <= IDLE;
        end else begin
            state_prev <= state;
            case (state)
                IDLE:
                    begin
                        if (btn_edge && keypoints_done_latched) begin
                            state <= O1KEY;
                        end
                    end
                O1KEY:
                    begin
                        if (!tx_img_busy_O1k && btn_edge) begin
                            state <= O1L1;
                        end
                        uart_txd <= O1k_txd;
                    end
                O1L1:
                    begin
                        if (!tx_img_busy_O1L1 && btn_edge) begin
                            state <= O1L2;
                        end
                        uart_txd <= O1L1_txd;
                    end
                O1L2:
                    begin
                        if (!tx_img_busy_O1L2 && btn_edge) begin
                            state <= O1L3;
                        end
                        uart_txd <= O1L2_txd;
                    end
                O1L3:
                    begin
                        if (!tx_img_busy_O1L3 && btn_edge) begin
                            state <= O2L1;
                        end
                        uart_txd <= O1L3_txd;
                    end
                O2L1:
                    begin
                        if (!tx_img_busy_O2L1 && btn_edge) begin
                            state <= O2L2;
                        end
                        uart_txd <= O2L1_txd;
                    end
                O2L2:
                    begin
                        if (!tx_img_busy_O2L2 && btn_edge) begin
                            state <= O2L3;
                        end
                        uart_txd <= O2L2_txd;
                    end
                O2L3:
                    begin
                        if (!tx_img_busy_O2L3 && btn_edge) begin
                            state <= O3L1;
                        end
                        uart_txd <= O2L3_txd;
                    end
                O3L1:
                    begin
                        if (!tx_img_busy_O3L1 && btn_edge) begin
                            state <= O3L2;
                        end
                        uart_txd <= O3L1_txd;
                    end
                O3L2:
                    begin
                        if (!tx_img_busy_O3L2 && btn_edge) begin
                            state <= O3L3;
                        end
                        uart_txd <= O3L2_txd;
                    end
                O3L3:
                    begin
                        if (!tx_img_busy_O3L3 && btn_edge) begin
                            state <= IDLE;
                        end
                        uart_txd <= O3L3_txd;
                    end
                default:
                    begin
                        state <= IDLE;
                    end
            endcase
        end
    end

    assign led[2] = (state == IDLE);
    assign led[3] = (state == O1L1);
    assign led[4] = (state == O1L2);
    assign led[5] = (state == O1L3);
    assign led[6] = (state == O2L1);
    assign led[7] = (state == O2L2);
    assign led[8] = (state == O2L3);
    assign led[9] = (state == O3L1);
    assign led[10] = (state == O3L2);
    assign led[11] = (state == O3L3);
    assign led[12] = (state == O1KEY);


    send_keypoints #(.BRAM_LENGTH(1000)) tx_keypt_O1 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O1KEY) && (state_prev != O1KEY)),//full_image_received
      .tx(O1k_txd),//uart_txd
      .data(O1_keypoint_read),
      .address(O1key_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O1k) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O1k;
    logic O1k_txd;

    // send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L1 (
    //   .clk(clk_100mhz),
    //   .rst_in(sys_rst),//sys_rst
    //   .img_ready((state == O1L1) && (state_prev != O1L1)),//full_image_received
    //   .tx(O1L1_txd),//uart_txd
    //   .data(O1L1_pixel_out),
    //   .address(O1L1_read_addr), // gets wired to the BRAM
    //   .tx_free(),
    //   .busy(tx_img_busy_O1L1) //or we could do img_sent whichever makes more sense
    // );
    logic tx_img_busy_O1L1;
    logic O1L1_txd;

    // send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L2 (
    //   .clk(clk_100mhz),
    //   .rst_in(sys_rst),//sys_rst
    //   .img_ready((state == O1L2) && (state_prev != O1L2)),//full_image_received
    //   .tx(O1L2_txd),//uart_txd
    //   .data(O1L2_pixel_out),
    //   .address(O1L2_read_addr), // gets wired to the BRAM
    //   .tx_free(),
    //   .busy(tx_img_busy_O1L2) //or we could do img_sent whichever makes more sense
    // );
    logic tx_img_busy_O1L2;
    logic O1L2_txd;

    // send_img #(.BRAM_LENGTH(WIDTH * HEIGHT)) tx_img_O1L3 (
    //   .clk(clk_100mhz),
    //   .rst_in(sys_rst),//sys_rst
    //   .img_ready((state == O1L3) && (state_prev != O1L3)),//full_image_received
    //   .tx(O1L3_txd),//uart_txd
    //   .data(O1L3_pixel_out),
    //   .address(O1L3_read_addr), // gets wired to the BRAM
    //   .tx_free(),
    //   .busy(tx_img_busy_O1L3) //or we could do img_sent whichever makes more sense
    // );
    logic tx_img_busy_O1L3;
    logic O1L3_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L1 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L1) && (state_prev != O2L1)),//full_image_received
      .tx(O2L1_txd),//uart_txd
      .data(O2L1_pixel_out),
      .address(O2L1_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L1) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L1;
    logic O2L1_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L2 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L2) && (state_prev != O2L2)),//full_image_received
      .tx(O2L2_txd),//uart_txd
      .data(O2L2_pixel_out),
      .address(O2L2_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L2) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L2;
    logic O2L2_txd;

    send_img #(.BRAM_LENGTH(WIDTH/2 * HEIGHT/2)) tx_img_O2L3 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O2L3) && (state_prev != O2L3)),//full_image_received
      .tx(O2L3_txd),//uart_txd
      .data(O2L3_pixel_out),
      .address(O2L3_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O2L3) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O2L3;
    logic O2L3_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L1 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L1) && (state_prev != O3L1)),//full_image_received
      .tx(O3L1_txd),//uart_txd
      .data(O3L1_pixel_out),
      .address(O3L1_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L1) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L1;
    logic O3L1_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L2 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L2) && (state_prev != O3L2)),//full_image_received
      .tx(O3L2_txd),//uart_txd
      .data(O3L2_pixel_out),
      .address(O3L2_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L2) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L2;
    logic O3L2_txd;

    send_img #(.BRAM_LENGTH(WIDTH/4 * HEIGHT/4)) tx_img_O3L3 (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == O3L3) && (state_prev != O3L3)),//full_image_received
      .tx(O3L3_txd),//uart_txd
      .data(O3L3_pixel_out),
      .address(O3L3_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy_O3L3) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy_O3L3;
    logic O3L3_txd;

    // always_comb begin
    //     case (state)
    //         O1L1:
    //             begin
    //                 uart_txd = O1L1_txd;
    //             end
    //         O1L2:
    //             begin
    //                 uart_txd = O1L2_txd;
    //             end
    //         O1L3:
    //             begin
    //                 uart_txd = O1L3_txd;
    //             end
    //         O2L1:
    //             begin
    //                 uart_txd = O2L1_txd;
    //             end
    //         O2L2:
    //             begin
    //                 uart_txd = O2L2_txd;
    //             end
    //         O2L3:
    //             begin
    //                 uart_txd = O2L3_txd;
    //             end
    //         O3L1:
    //             begin
    //                 uart_txd = O3L1_txd;
    //             end
    //         O3L2:
    //             begin
    //                 uart_txd = O3L2_txd;
    //             end
    //         O3L3:
    //             begin
    //                 uart_txd = O3L3_txd;
    //             end
    //     endcase
    // end
  
    
endmodule // top_level

`default_nettype wire
