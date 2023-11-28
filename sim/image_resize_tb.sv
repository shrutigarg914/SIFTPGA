`timescale 1ns / 1ps
`default_nettype none

module img_resize_tb;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [7:0] pixel_in;
    logic [$clog2(64)-1:0] center_addr_x;
    logic [$clog2(64)-1:0] center_addr_y;
    logic valid_in;
    logic [7:0] data_out;
    logic [$clog2(32)*2-1:0] addr_out;
    logic valid_out;

    image_half #(.BIT_DEPTH(8),
                 .NEW_WIDTH(32))
        downsizer(
            .clk_in(clk_in),
            .rst_in(rst_in),
            .data_in(pixel_in),
            .data_x_in(center_addr_x),
            .data_y_in(center_addr_y),
            .data_valid_in(valid_in),
            .data_out(data_out),
            .data_addr_out(addr_out),
            .data_valid_out(valid_out)
    );
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("resize.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,img_resize_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        center_addr_x = 0;
        center_addr_y = 0;
        valid_in = 0;
        #10  //wait a little bit of time at beginning
        rst_in = 1; //reset system
        #10; //hold high for a few clock cycles
        rst_in=0;
        #10;
        
        for (int i = 0; i<64; i= i+1)begin
            for (int j=0; j<64; j=j+1) begin
                pixel_in = i + j;
                valid_in = 1;
                #10
                valid_in = 0;
                #10
                center_addr_x = center_addr_x + 1;
            end
            center_addr_y = center_addr_y + 1;
            center_addr_x = 0;
        end
        

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule //gaussian_blur_tb

`default_nettype wire
