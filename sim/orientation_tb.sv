`timescale 1ns / 1ps
`default_nettype none

module orientation_tb;
    parameter WIDTH = 8;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;

    // make two dual port BRAMs for x and y with 3x3 width and 8 bit depth
    // write test cases to them
    // loop through 3x3 coords and print out orientation outputs

    gradient_orientation #(
        WIDTH = 3,
        HEIGHT = 3,
        BIT_DEPTH = 8,
    )
    orientation(.clk_in(clk_in), .rst_in(rst_in),
                .x_read_addr(),
                .x_read_addr_valid(),
                .x_pixel_in(),
                .y_read_addr(),
                .y_read_addr_valid(),
                .y_pixel_in(),
                .center_addr_x(),
                .center_addr_y(),
                .valid_in(), 
                .valid_out(),
                .bin_out(),
                .state_num());
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("orientation.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,orientation_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule // orientation_tb

`default_nettype wire
