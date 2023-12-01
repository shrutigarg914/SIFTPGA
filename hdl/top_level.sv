`timescale 1ns / 1ps
`default_nettype none

// receive two images
// pass them through dog
// transmit result to laptop
// NOTE that we can't send 9 bits over tx
// divide the results from dog by 2 before sending
// can multiply by 2 on laptop.
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
    // manually flip the switch to receive images in the other BRAM
    logic image_number;
    assign image_number = sw[0];
    logic old_image_number;

    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pixel_addr <= 0;
        full_image_received <= 1'b0;
      end
      else if (valid_o_edge) begin
        pixel_addr <= pixel_addr + 1;
        if (pixel_addr== DIMENSION*DIMENSION - 1) begin
          full_image_received <= 1'b1;
          pixel_addr <= 0;
        end
      end else if (old_image_number!=image_number) begin
        full_image_received <= 1'b0;
      end
      old_image_number <= image_number;
    end
    // the start image BRAM
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 64*64 image with 16384 pixels total
    img_1 (
    .addra(pixel_addr),
    .clka(clk_100mhz),
    .wea(valid_o & (~image_number)),
    .dina(rx_data),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(dog_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(1'b1),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(img1_out)
  );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 64*64 image with 16384 pixels total
    img_2 (
    .addra(pixel_addr),
    .clka(clk_100mhz),
    .wea(valid_o & image_number),
    .dina(rx_data),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(dog_address),// transformed lookup pixel
    .dinb(),
    .clkb(clk_100mhz),
    .web(1'b0),
    .enb(1'b1),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(img2_out)
  );
  logic ready_for_dog;

  logic dog_busy;
  assign ready_for_dog = full_image_received & image_number;
  assign led[4] = ready_for_dog;
  logic signed [8:0] dog_out;
  // assign pixel_out = {dog_out[8], dog_out[7:1]};
  logic start_dog;
  logic dog_was_busy;
  assign led[15] = dog_was_busy;
  logic [2:0] dog_state_counter;

  typedef enum {BUILDING=0, START=1, STARTED=2} dog_state;
  dog_state dog_state_keeper;
  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      dog_state_keeper <= BUILDING;
      dog_was_busy <= 1'b0;
      dog_state_counter <= 2'b00;
    end else begin
      case(dog_state_keeper)
        BUILDING: if (ready_for_dog) begin
          dog_state_counter <= dog_state_counter + 2'b01;
          if (dog_state_counter==2'b11) begin
            dog_state_keeper <= START;
          end
        end else begin
          dog_state_counter <= 2'b00;
        end
        START: dog_state_keeper <= STARTED;
        STARTED: dog_state_keeper <= STARTED;
      endcase
      if (dog_busy) begin
        dog_was_busy <= 1'b1;
      end
    end
  end

  assign start_dog = (dog_state_keeper==START);
  assign led[14] = 1'b0;
  assign led[13] = btn[2];
  assign led[10:9] = dog_state_keeper;

  dog #(.DIMENSION(DIMENSION)) builder (
    .clk(clk_100mhz),
    .rst_in(sys_rst),
    .bram_ready(start_dog),
    .sharper_pix(img1_out),
    .fuzzier_pix(img2_out),
    .busy(dog_busy),
    .address(dog_address),
    .data_out(dog_out),
    .wea(dog_wea),
    .state_num(led[6:5])
  );

  // assign led[6:5] = dog_state;
  // assign led[13:6] 
  logic dog_wea;

  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(9), // we expect 8 bit greyscale images
    .RAM_DEPTH(DIMENSION*DIMENSION)) //we expect a 64*64 image with 16384 pixels total
    out (
    .addra(dog_address),
    .clka(clk_100mhz),
    .wea(dog_wea), // FIX THIS
    .dina(dog_out),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(read_pixel_addr),// transformed lookup pixel
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
    logic dog_edge;
    assign dog_edge = ~old_dog_pulse & dog_pulse;

    //rest of the logic here
    logic btn_pulse;
    logic old_btn_pulse;
    debouncer btn1_db(.clk_in(clk_100mhz),
                    .rst_in(sys_rst),
                    .dirty_in(btn[1]),
                    .clean_out(btn_pulse));
    logic dog_pulse;
    logic old_dog_pulse;
    debouncer btn2_db(.clk_in(clk_100mhz),
                    .rst_in(sys_rst),
                    .dirty_in(btn[2]),
                    .clean_out(dog_pulse));
 
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
      old_dog_pulse <= dog_pulse;
    end

    send_img  tx_img (
      .clk(clk_100mhz),
      .rst_in(sys_rst),//sys_rst
      .img_ready(btn_edge),//full_image_received
      .tx(uart_txd),//uart_txd
      .data({pixel_out[8], pixel_out[7:1]}),
      .address(read_pixel_addr), // gets wired to the BRAM
      .tx_free(led[2]),
      // .out_state(led[4:3]),
      .busy(tx_img_busy) //or we could do img_sent whichever makes more sense
    );
  logic tx_img_busy;

  logic signed [8:0] pixel_out;
  logic [7:0] img1_out, img2_out;
  logic [13:0] read_pixel_addr, dog_address;
  assign led[1] = tx_img_busy;
  // assign led[15:4] = dog_address[12:1];
  
    
endmodule // top_level

`default_nettype wire
