`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire [15:0] sw, //all 16 input slide switches
  input wire clk_100mhz,
  input wire uart_rxd,
  input wire [3:0] btn, //all four momentary button switches
  output logic uart_txd,
  output logic [15:0] led //16 green output LEDs (located right above switches)
  );
    logic sys_rst;
    assign sys_rst = btn[0];

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
        if (pixel_addr==14'b11_1111_1111_1111) begin
          full_image_received <= 1'b1;
        end
      end
    end
    // the start image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(128*128)) //we expect a 128*128 image with 16384 pixels total
    rx_img (
    .addra(pixel_addr),
    .clka(clk_100mhz),
    .wea(valid_o),
    .dina(rx_data),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(read_pixel_addr),//transformed lookup pixel
    .dinb(),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(1'b1),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(pixel_out)
  );

    // TODO: when btn[1] pressed, send what's stored in the output BRAM to the laptop
    
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


  logic [7:0] pixel_out;
  logic [13:0] read_pixel_addr;
  logic sending_img, send_pixel;
  logic [3:0] counter;
  assign led[1] = btn_edge;
  assign led[2] = sending_img;
  assign led[4:3] = counter;
  assign led[5] = done_o;
  assign led[6] = send_pixel;
  logic old_done_o;
  // assign led[15:5] = read_pixel_addr[10:0];

  // if we have received a full image,
  always_ff @(posedge clk_100mhz) begin
    old_done_o <= done_o;
    if (sys_rst) begin
      read_pixel_addr<=0;
      sending_img <= 1'b0;
      counter <= 0;
    end else begin
      if (full_image_received) begin
      if (btn_edge & ~sending_img) begin
        sending_img <=1'b1;
        counter <= 0;
        read_pixel_addr <= 0;
      end
      if (sending_img) begin
        if (done_o & ~old_done_o) begin 
          counter <=0;
          read_pixel_addr<=read_pixel_addr+1;
          send_pixel<= 1'b0;
        end else if (counter==2'b10) begin
          data_i<=pixel_out;
          counter<= counter + 1;
          send_pixel <= 1'b1;
        end else if(counter==2'b11) begin
          send_pixel <=1'b0;
        end else begin
          counter <= counter + 1;
        end
      end
    end
  end 
  end
  
  // assign start_i = btn_edge;
  uart_tx #(.CLOCKS_PER_BAUD(50))
    utx (
      .clk(clk_100mhz),
      .data_i(data_i),
      .start_i(send_pixel),
      .done_o(done_o),
      .tx(uart_txd));
  
    
endmodule // top_level

`default_nettype wire
