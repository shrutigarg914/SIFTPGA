`timescale 1ns / 1ps
`default_nettype none

module gaussian_blur_tb;
    parameter WIDTH = 8;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [WIDTH*3-1:0] r0;
    logic [WIDTH*3-1:0] r1;
    logic [WIDTH*3-1:0] r2;
    logic valid_in;
    logic [WIDTH-1:0] data_out;
    logic valid_out;

    gaussian blur(.clk_in(clk_in), .rst_in(rst_in),
                         .r0_data_in(r0),
                         .r1_data_in(r1),
                         .r2_data_in(r2),
                         .data_valid_in(valid_in),
                         .data_out(data_out),
                         .data_valid_out(valid_out), 
                         .error_out(),
                         .busy_out());
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("blur.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,gaussian_blur_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        r0 = 24'h00_00_00;
        r1 = 24'h00_00_00;
        r2 = 24'h00_00_00;
        valid_in = 0;
        #10  //wait a little bit of time at beginning
        rst_in = 1; //reset system
        #10; //hold high for a few clock cycles
        rst_in=0;
        #10;

        // Test 1 
        $display("Test 1, all zeros");
        r0 = 24'h00_00_00;
        r1 = 24'h00_00_00;
        r2 = 24'h00_00_00;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 1 done");
        $display("Blurred pixel Value:", data_out);

        // Test 2
        $display("Test 2, all ones");
        r0 = 24'h01_01_01;
        r1 = 24'h01_01_01;
        r2 = 24'h01_01_01;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 2 done");
        $display("Blurred pixel Value:", data_out);

        // Test 3
        $display("Test 3, 1-9 square");
        r0 = 24'h01_02_03;
        r1 = 24'h04_05_06;
        r2 = 24'h07_08_09;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 3 done");
        $display("Blurred pixel Value:", data_out);

        // Test 4
        $display("Test 4, all 255");
        r0 = 24'hFF_FF_FF;
        r1 = 24'hFF_FF_FF;
        r2 = 24'hFF_FF_FF;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 4 done");
        $display("Blurred pixel Value:", data_out);

        // Test 5
        $display("Test 5, 255 middle");
        r0 = 24'h00_00_00;
        r1 = 24'h00_FF_00;
        r2 = 24'h00_00_00;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 5 done");
        $display("Blurred pixel Value:", data_out);

        // Test 6
        $display("Test 6, random numbers");
        r0 = 24'h86_02_2E;
        r1 = 24'h1E_19_00;
        r2 = 24'h01_09_FF;
        valid_in = 1;
        #10
        valid_in = 0;
        #100;
        $display("Test 6 done");
        $display("Blurred pixel Value:", data_out);
        

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule //gaussian_blur_tb

`default_nettype wire
