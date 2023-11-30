`timescale 1ns / 1ps
`default_nettype none

module dog_tb;

    logic clk;
    logic sys_rst;
    logic br;
    logic [7:0] img1_out, img2_out;
    logic dog_busy, dog_out;
    logic [13:0] dog_address;
    logic [1:0] dog_state;

    dog #(.DIMENSION(4)) builder (
    .clk(clk),
    .rst_in(sys_rst),
    .bram_ready(br),
    .sharper_pix(img1_out),
    .fuzzier_pix(img2_out),
    .busy(dog_busy),
    .address(dog_address),
    .data_out(dog_out),
    .state_num(dog_state)
  );

//     xilinx_true_dual_port_read_first_2_clock_ram #(
//     .RAM_WIDTH(8), // we expect 8 bit greyscale images
//     .RAM_DEPTH(128*128)) //we expect a 128*128 image with 16384 pixels total
//     rx_img (
//     .addra(),
//     .clka(),
//     .wea(),
//     .dina(),
//     .ena(1'b0),
//     .regcea(1'b1),
//     .rsta(sys_rst),
//     .douta(), //never read from this side
//     .addrb(read_pixel_addr),// transformed lookup pixel
//     .dinb(),
//     .clkb(clk),
//     .web(1'b0),
//     .enb(1'b1),
//     .rstb(sys_rst),
//     .regceb(1'b1),
//     .doutb(pixel_out)
//   );

    always begin
        #5;  // every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk = !clk;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("dog.vcd"); //file to store value change dump (vcd)
        $dumpvars(0, dog_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk = 0; //initialize clk (super important)
        br = 0;
        img1_out = 0;
        img2_out = 0;
        #10;  //wait a little bit of time at beginning
        sys_rst= 1'b1;
        #10;
        sys_rst =1'b0;
        #50;
        br = 1'b1;
        #10;
        br = 1'b0;
        #4000;
        // while (!done_o) begin
        //     #10;
        // end
        $display("Sent!"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire