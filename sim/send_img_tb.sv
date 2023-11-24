`timescale 1ns / 1ps
`default_nettype none

module send_img_tb;

    logic clk;
    logic sys_rst;//sys_rst
    logic btn_edge;//full_image_received
    logic uart_txd;//uart_txd
    logic [7:0] pixel_out;
    logic [13:0] read_pixel_addr; // gets wired to the BRAM
    logic tx_img_busy; //or we could do img_sent whichever makes more sense
    logic [1:0] out_state;
    logic tx_free;
    logic send;
    assign cond = ~tx_free & send;

    logic cond;
    send_img  tx_img (
      .clk(clk),
      .rst_in(sys_rst),//sys_rst
      .img_ready(btn_edge),//full_image_received
      .tx(uart_txd),//uart_txd
      .data(pixel_out),
      .address(read_pixel_addr), // gets wired to the BRAM
      .out_state(out_state),
      .send(send),
      .tx_free(tx_free),
      .busy(tx_img_busy) //or we could do img_sent whichever makes more sense
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
        $dumpfile("send_img.vcd"); //file to store value change dump (vcd)
        $dumpvars(0, send_img_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk = 0; //initialize clk (super important)
        btn_edge = 0;
        pixel_out = 0;
        uart_txd = 1'b1;
        #10;  //wait a little bit of time at beginning
        sys_rst= 1'b1;
        #10;
        sys_rst =1'b0;
        btn_edge = 1'b1;

        // start_i = 1;
        #5000;
        
        
        // start_i = 0;

        // data_i = 8'b1111_1111;
        // while (!done_o) begin
        //     #10;
        // end
        $display("Sent!"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire