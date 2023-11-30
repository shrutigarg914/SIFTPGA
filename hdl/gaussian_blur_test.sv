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

    parameter DIMENSION = 64;
    parameter BIT_DEPTH = 8;

    logic [13:0] pixel_addr;
    logic [7:0] rx_data;

    logic valid_o;
    logic valid_o_edge;
    logic old_valid_o;

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
    assign led[1] = blur_done;

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
        if (pixel_addr== DIMENSION*DIMENSION - 1) begin
          full_image_received <= 1'b1;
          start_blurring <= 1'b1;
        end
      end

      if (start_blurring) begin
        start_blurring <= 0;
      end
    end

    // the start image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(8), // we expect 8 bit greyscale images
        .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 64*64 image with 16384 pixels total
        rx_img (
        .addra(pixel_addr),
        .clka(clk_100mhz),
        .wea(valid_o),
        .dina(rx_data),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(read_pixel_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(read_pixel_addr_valid),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(pixel_out)
    );
  
    logic [7:0] pixel_out;
    logic [13:0] read_pixel_addr;
    logic read_pixel_addr_valid;
    logic [1:0] read_pixel_addr_valid_pipe;
    always_ff @(posedge clk_100mhz)begin
        read_pixel_addr_valid_pipe[0] <= read_pixel_addr_valid;
        read_pixel_addr_valid_pipe[1] <= read_pixel_addr_valid_pipe[0];

        kernel_ind_pipe[0] <= kernel_ind;
        kernel_ind_pipe[1] <= kernel_ind_pipe[0];
    end

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
    logic start_blurring;
    logic [$clog2(DIMENSION)-1:0] center_addr_x;
    logic [$clog2(DIMENSION)-1:0] center_addr_y;
    logic [$clog2(DIMENSION)-1:0] center_addr_x_prev;
    logic [$clog2(DIMENSION)-1:0] center_addr_y_prev;
    logic [3:0] kernel_ind;
    logic [3:0] kernel_ind_pipe [1:0];
    logic[BIT_DEPTH*3-1:0] row1;
    logic[BIT_DEPTH*3-1:0] row2;
    logic[BIT_DEPTH*3-1:0] row3;
    logic blur_data_valid_in;
    logic[BIT_DEPTH-1:0] blur_out;
    logic blur_data_valid_out;
    logic blur_done;

    initial begin
        center_addr_x = 0;
        center_addr_y = 0;
        blur_data_valid_in = 0;
        blur_data_valid_out = 0;
        row1 = 0;
        row2 = 0;
        row3 = 0;
        blur_out = 0;
        kernel_ind = 0;
        blur_done = 0;
        start_blurring = 0;
    end

    // 3 stage pipeline, collect rows, do blur, write to BRAM
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        center_addr_x <= 0;
        center_addr_y <= 0;
        center_addr_x_prev <= 0;
        center_addr_y_prev <= 0;
        blur_data_valid_in <= 0;
        blur_data_valid_out <= 0;
        kernel_ind <= 0;
        blur_done <= 0;
        start_blurring <= 0;
      end else begin
        if (full_image_received && ~blur_done) begin
            // we either just started the blurring part or we just finished reading the last pixel from the BRAM
            if (read_pixel_addr_valid_pipe[1] || start_blurring) begin 
                if (!start_blurring) begin
                    // write the previous read result to correct row
                    case (kernel_ind_pipe[1]) // use the index from when we started reading because we've changed it by now
                        0: row1[BIT_DEPTH*3-1:BIT_DEPTH*2] <= pixel_out;
                        1: row1[BIT_DEPTH*2-1:BIT_DEPTH] <= pixel_out;
                        2: row1[BIT_DEPTH-1:0] <= pixel_out;
                        3: row2[BIT_DEPTH*3-1:BIT_DEPTH*2] <= pixel_out;
                        4: row2[BIT_DEPTH*2-1:BIT_DEPTH] <= pixel_out;
                        5: row2[BIT_DEPTH-1:0] <= pixel_out;
                        6: row3[BIT_DEPTH*3-1:BIT_DEPTH*2] <= pixel_out;
                        7: row3[BIT_DEPTH*2-1:BIT_DEPTH] <= pixel_out;
                        8: row3[BIT_DEPTH-1:0] <= pixel_out;
                    endcase
                end

                // update read pixel addr based on current center and kernel_ind
                case (kernel_ind)
                0:
                    read_pixel_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * DIMENSION;
                1:
                    read_pixel_addr <= center_addr_x 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * DIMENSION;
                2:
                    read_pixel_addr <= ((center_addr_x == DIMENSION - 1) ? center_addr_x : center_addr_x + 1) 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * DIMENSION;
                3:
                    read_pixel_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + center_addr_y * DIMENSION;
                4:
                    read_pixel_addr <= center_addr_x 
                                        + center_addr_y * DIMENSION;
                5:
                    read_pixel_addr <= ((center_addr_x == DIMENSION - 1) ? center_addr_x : center_addr_x + 1) 
                                        + center_addr_y * DIMENSION;
                6:
                    read_pixel_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + ((center_addr_y == DIMENSION - 1) ? center_addr_y : center_addr_y + 1) * DIMENSION;
                7:
                    read_pixel_addr <= center_addr_x 
                                        + ((center_addr_y == DIMENSION - 1) ? center_addr_y : center_addr_y + 1) * DIMENSION;
                8:
                    read_pixel_addr <= ((center_addr_x == DIMENSION - 1) ? center_addr_x : center_addr_x + 1) 
                                        + ((center_addr_y == DIMENSION - 1) ? center_addr_y : center_addr_y + 1) * DIMENSION;
                endcase
                read_pixel_addr_valid <= 1;

                // update kernel_ind
                if (kernel_ind == 8) begin
                    blur_data_valid_in <= 1; // start blur module (just finished collecting rows)
                    // reset kernel_ind and go to next pixel (inc center x, y)
                    kernel_ind <= 0;
                    center_addr_x_prev <= center_addr_x;
                    center_addr_y_prev <= center_addr_y;
                    if (center_addr_x == DIMENSION - 1) begin
                        if (center_addr_y == DIMENSION - 1) begin
                            blur_done <= 1;
                        end else begin
                            center_addr_x <= 0;
                            center_addr_y <= center_addr_y + 1;
                        end
                    end else begin
                        center_addr_x <= center_addr_x + 1;
                    end
                end else begin
                    kernel_ind <= kernel_ind + 1;
                end
            end

        end
      end
    end

    // the start blurred image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 64*64 image with 16384 pixels total
    blur_img (
        .addra(center_addr_x_prev + center_addr_y_prev * DIMENSION),
        .clka(clk_100mhz),
        .wea(blur_data_valid_out),
        .dina(blur_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(read_blur_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_100mhz),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(blur_stored_out)
    );
    logic [13:0] read_blur_addr;
    logic [BIT_DEPTH-1:0] blur_stored_out;

    // when btn[1] pressed if gaussian blur is done, send what's stored in the blur BRAM to the laptop
    
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
      .img_ready(btn_edge && blur_done),//full_image_received
      .tx(uart_txd),//uart_txd
      .data(blur_stored_out),
      .address(read_blur_addr), // gets wired to the BRAM
      .tx_free(),
      .busy(tx_img_busy) //or we could do img_sent whichever makes more sense
    );
    logic tx_img_busy;

    assign led[13:2] = center_addr_x_prev + center_addr_y_prev * DIMENSION;
  
    
endmodule // top_level

`default_nettype wire
