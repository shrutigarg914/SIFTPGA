// python send_image_receive_resized.py util/buff_doge.png
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

    uart_rx #(.CLOCKS_PER_BAUD(50))
      urx (
        .clk(clk_100mhz),
        .rx(uart_rxd),
        .data_o(rx_data),
        .valid_o(valid_o)
      );
      logic valid_o;
      logic [7:0] rx_data;

    parameter BIT_DEPTH = 8;
    parameter WIDTH = 64;
    parameter HEIGHT = 64;

    logic [$clog2(WIDTH)-1:0] center_addr_x;
    logic [$clog2(HEIGHT)-1:0] center_addr_y;
    logic image_collect_done;
    logic all_done;

    logic [7:0] resize_out;
    logic [$clog2(32)*2-1:0] resize_out_addr;
    logic resize_out_valid;

    initial begin
        center_addr_x = 0;
        center_addr_y = 0;
        image_collect_done = 0;
    end

    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            center_addr_x <= 0;
            center_addr_y <= 0;
            image_collect_done <= 0;
        end else begin
            if (valid_o && !image_collect_done) begin
                if (center_addr_x == WIDTH - 1) begin
                    if (center_addr_y == HEIGHT - 1) begin
                        image_collect_done <= 1;
                    end else begin
                        center_addr_x <= 0;
                        center_addr_y <= center_addr_y + 1;
                    end
                end else begin
                    center_addr_x <= center_addr_x + 1;
                end
            end
        end
    end

    image_half #(.BIT_DEPTH(8),
                 .NEW_WIDTH(32))
        downsizer(
            .clk_in(clk_100mhz),
            .rst_in(sys_rst),
            .data_in(rx_data),
            .data_x_in(center_addr_x),
            .data_y_in(center_addr_y),
            .data_valid_in(valid_o),
            .data_out(resize_out),
            .data_addr_out(resize_out_addr),
            .data_valid_out(resize_out_valid),
            .done_out()
    );

    //two-port BRAM used to hold downsided image
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
        .RAM_DEPTH(32*32))
        frame_buffer (
        .addra(resize_out_addr),
        .clka(clk_100mhz),
        .wea(resize_out_valid),
        .dina(resize_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(read_pixel_addr), // lookup pixel
        .dinb(16'b0),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(pixel_out)
    );

    logic btn_edge;
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

    send_img #(.BRAM_LENGTH(32 * 32)) 
        tx_img (
        .clk(clk_100mhz),
        .rst_in(sys_rst),//sys_rst
        .img_ready(btn_edge && image_collect_done),//full_image_received
        .tx(uart_txd),//uart_txd
        .data(pixel_out),
        .address(read_pixel_addr), // gets wired to the BRAM
        .tx_free(led[2]),
        // .out_state(led[4:3]),
        .busy(tx_img_busy) //or we could do img_sent whichever makes more sense
    );
  logic tx_img_busy;

  logic [7:0] pixel_out;
  logic [13:0] read_pixel_addr;
  assign led[14:3] = read_pixel_addr;
//   assign led[1] = tx_img_busy;
//   assign led[15:3] = read_pixel_addr[12:0];


endmodule // top_level

`default_nettype wire
