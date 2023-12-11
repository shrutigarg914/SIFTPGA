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

    logic [$clog2(WIDTH * HEIGHT)-1:0] pixel_addr;
    logic [BIT_DEPTH-1:0] rx_data;

    logic valid_o;
    logic valid_o_edge;
    logic old_valid_o;
    logic start_gradient;
    logic gradient_done;
    logic gradient_done_latched;

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
    assign led[1] = gradient_done_latched;

    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pixel_addr <= 0;
        full_image_received <= 1'b0;
        gradient_done_latched <= 0;
        start_gradient <= 0;
      end
      else if (valid_o_edge) begin
        // pixel <= data_o; I'm assuming that data doesn't need to be held
        // for more than one cycle for writin to the BRAM
        pixel_addr <= pixel_addr + 1;
        if (pixel_addr== WIDTH*HEIGHT - 1) begin
          full_image_received <= 1'b1;
          start_gradient <= 1'b1;
        end
      end

      if (gradient_done) begin
        gradient_done_latched <= 1;
      end
    end

    // the start image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(8), // we expect 8 bit greyscale images
        .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
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
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] x_write_addr;
    logic x_write_valid;
    logic [BIT_DEPTH-1:0] x_pixel_out;
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] y_write_addr;
    logic y_write_valid;
    logic [BIT_DEPTH-1:0] y_pixel_out;

    // the start x gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    x_grad (
        .addra(x_write_addr),
        .clka(clk_100mhz),
        .wea(x_write_valid),
        .dina(x_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(x_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(x_stored_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] x_read_addr;
    logic [BIT_DEPTH-1:0] x_stored_out;

    // the start y gradient BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(WIDTH*HEIGHT)) //we expect a 64*64 image with 4096 pixels total
    y_grad (
        .addra(y_write_addr),
        .clka(clk_100mhz),
        .wea(y_write_valid),
        .dina(y_pixel_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(y_read_addr),
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(y_stored_out)
    );
    logic [$clog2(WIDTH * HEIGHT)-1:0] y_read_addr;
    logic [BIT_DEPTH-1:0] y_stored_out;

    logic[2:0] state_num;
    assign led[7:5] = state_num;

    gradient_image #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT))
    gradient (.clk_in(clk_100mhz), .rst_in(sys_rst),
                         .ext_read_addr(read_addr),
                         .ext_read_addr_valid(read_addr_valid),
                         .ext_pixel_in(pixel_in),
                         .x_write_addr(x_write_addr),
                         .x_write_valid(x_write_valid),
                         .x_pixel_out(x_pixel_out), 
                         .y_write_addr(y_write_addr),
                         .y_write_valid(y_write_valid),
                         .y_pixel_out(y_pixel_out), 
                         .start_in(start_gradient),
                         .gradient_done(gradient_done),
                         .state_num(state_num));

    // when btn[1] pressed if gradient is done, send what's stored in the x and y BRAMs to the laptop
    
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

    typedef enum {IDLE=0, X=1, Y=2} tx_state;
    tx_state state;
    tx_state state_prev;

    send_img  tx_img_x (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == X) && (state_prev != X)),//full_image_received
      .tx(x_uart_txd),//uart_txd
      .data(x_stored_out),
      .address(x_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(x_tx_img_busy) //or we could do img_sent whichever makes more sense
    );
    logic x_tx_img_busy;
    logic x_uart_txd;

    send_img  tx_img_y (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready((state == Y) && (state_prev != Y)),//full_image_received
      .tx(y_uart_txd),//uart_txd
      .data(y_stored_out),
      .address(y_read_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(y_tx_img_busy) //or we could do img_sent whichever makes more sense
    );
    logic y_tx_img_busy;
    logic y_uart_txd;

    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        state <= IDLE;
      end else begin
        state_prev <= state;
        case (state)
          IDLE:
          begin
            if (btn_edge && gradient_done_latched) begin
                state <= X;
            end
          end
          X:
          begin
            if (!x_tx_img_busy && btn_edge) begin
                state <= Y;
            end
            uart_txd <= x_uart_txd;
          end
          Y:
          begin
            if (!y_tx_img_busy && btn_edge) begin
                state <= IDLE;
            end
            uart_txd <= y_uart_txd;
          end
        endcase
      end
    end
    
    assign led[2] = (state == IDLE);
    assign led[3] = (state == X);
    assign led[4] = (state == Y);

    
endmodule // top_level

`default_nettype wire
