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
    
    logic start_i;
    logic done_o;
    logic [7:0] data_i;
    // assign data_i = sw[7:0];
    assign start_i = all_done;
  
    logic btn_pulse;
    logic old_btn_pulse;
    logic btn_edge;
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

    uart_tx #(.CLOCKS_PER_BAUD(33))
     utx (
        .clk(clk_100mhz),
        .data_i(data_i),
        .start_i(start_i),
        .done_o(done_o),
        .tx(uart_txd));
    uart_rx #(.CLOCKS_PER_BAUD(33))
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

    logic [10:0] center_addr_x;
    logic [10:0] center_addr_y;
    logic image_collect_done;
    logic all_done;

    logic [7:0] original_pixel;
    logic valid_addr_read;
    logic [7:0] resize_out;
    logic [10:0] resize_out_addr;
    logic resize_out_valid;

    initial begin
        center_addr_x = 0;
        center_addr_y = 0;
        image_collect_done = 0;
        all_done = 0;
        valid_addr_read = 0;
    end

    always_ff @(posedge clk_100mhz) begin
        if (!all_done) begin
            if (image_collect_done) begin
                if (valid_addr_read) begin
                    if (center_addr_x == WIDTH - 1) begin
                        if (center_addr_y == HEIGHT - 1) begin
                            all_done <= 1;
                        end else begin
                            center_addr_x <= 0;
                            center_addr_y <= center_addr_y + 1;
                        end
                    end else begin
                        center_addr_x <= center_addr_x + 1;
                    end
                    valid_addr_read <= 0;
                end
                if (valid_img_read_addr_pipe[1]) begin
                    valid_addr_read <= 1;
                end
            end else begin
                if (valid_o) begin
                    if (center_addr_x == WIDTH - 1) begin
                        if (center_addr_y == HEIGHT - 1) begin
                            image_collect_done <= 1;
                            center_addr_x <= 0;
                            center_addr_y <= 0;
                            valid_addr_read <= 1;
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
    end

    //two-port BRAM used to hold received image
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(BIT_DEPTH), //each entry in this memory is BIT_DEPTH bits
        .RAM_DEPTH(WIDTH*HEIGHT))
        frame_buffer (
        .addra(center_addr_x + center_addr_y * HEIGHT),
        .clka(clk_100mhz),
        .wea(valid_o),
        .dina(rx_data),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(center_addr_x + center_addr_y * HEIGHT), // lookup pixel
        .dinb(16'b0),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(valid_addr_read),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(original_pixel)
    );

    image_half #(.BIT_DEPTH(8),
                 .NEW_HEIGHT(32))
        downsizer(
            .clk_in(clk_100mhz),
            .rst_in(sys_rst),
            .data_in(original_pixel),
            .data_x_in(center_addr_x),
            .data_y_in(center_addr_y),
            .data_valid_in(valid_img_read_addr_pipe[1]),
            .data_out(resize_out),
            .data_addr_out(resize_out_addr),
            .data_valid_out(resize_out_valid),
            .error_out(),
            .busy_out()
    );

    logic [1:0] valid_img_read_addr_pipe;
    always_ff @(posedge clk_100mhz)begin
        valid_img_read_addr_pipe[0] <= valid_addr_read;
        valid_img_read_addr_pipe[1] <= valid_img_read_addr_pipe[0];
    end

    // use switches+buttons
    always_ff @(posedge clk_100mhz) begin
        if (resize_out_valid) begin
            data_i <= resize_out;
        end
    end
endmodule // top_level

`default_nettype wire
