`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"util/X`"
`endif  /* ! SYNTHESIS */

module gaussian_pyramid_tb;
    parameter BIT_DEPTH = 8;
    parameter WIDTH = 64;
    parameter HEIGHT = 64;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;

    logic [$clog2(WIDTH * HEIGHT)-1:0] read_addr;
    logic read_addr_valid;
    logic [BIT_DEPTH-1:0] pixel_in;
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L1_write_addr;
    logic O1L1_write_valid;
    logic [BIT_DEPTH-1:0] O1L1_pixel_in;
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L2_write_addr;
    logic O1L2_write_valid;
    logic [BIT_DEPTH-1:0] O1L2_pixel_in;

    logic [$clog2(WIDTH * HEIGHT)-1:0] O1L3_write_addr;
    logic O1L3_write_valid;
    logic [BIT_DEPTH-1:0] O1L3_pixel_in;

    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L1_write_addr;
    logic O2L1_write_valid;
    logic [BIT_DEPTH-1:0] O2L1_pixel_in;

    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L2_write_addr;
    logic O2L2_write_valid;
    logic [BIT_DEPTH-1:0] O2L2_pixel_in;

    logic [$clog2(WIDTH/2 * HEIGHT/2)-1:0] O2L3_write_addr;
    logic O2L3_write_valid;
    logic [BIT_DEPTH-1:0] O2L3_pixel_in;

    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L1_write_addr;
    logic O3L1_write_valid;
    logic [BIT_DEPTH-1:0] O3L1_pixel_in;

    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L2_write_addr;
    logic O3L2_write_valid;
    logic [BIT_DEPTH-1:0] O3L2_pixel_in;

    logic [$clog2(WIDTH/4 * HEIGHT/4)-1:0] O3L3_write_addr;
    logic O3L3_write_valid;
    logic [BIT_DEPTH-1:0] O3L3_pixel_in;

    logic start_pyramid;
    logic pyramid_done;

    // the start image BRAM
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(WIDTH * HEIGHT),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) image (
        .addra(read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(read_addr_valid),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(pixel_in)      // RAM output data, width determined from RAM_WIDTH
    );

    gaussian_pyramid #(
        .BIT_DEPTH(BIT_DEPTH),
        .TOP_WIDTH(WIDTH),
        .TOP_HEIGHT(HEIGHT))
    pyramid (.clk_in(clk_in), .rst_in(rst_in),
                         .ext_read_addr(read_addr),
                         .ext_read_addr_valid(read_addr_valid),
                         .ext_pixel_in(pixel_in),
                         .O1L1_write_addr(O1L1_write_addr),
                         .O1L1_write_valid(O1L1_write_valid),
                         .O1L1_pixel_out(O1L1_pixel_in), 
                         .O1L2_write_addr(O1L2_write_addr),
                         .O1L2_write_valid(O1L2_write_valid),
                         .O1L2_pixel_out(O1L2_pixel_in), 
                         .O1L3_write_addr(O1L3_write_addr),
                         .O1L3_write_valid(O1L3_write_valid),
                         .O1L3_pixel_out(O1L3_pixel_in), 
                         .O2L1_write_addr(O2L1_write_addr),
                         .O2L1_write_valid(O2L1_write_valid),
                         .O2L1_pixel_out(O2L1_pixel_in), 
                         .O2L2_write_addr(O2L2_write_addr),
                         .O2L2_write_valid(O2L2_write_valid),
                         .O2L2_pixel_out(O2L2_pixel_in), 
                         .O2L3_write_addr(O2L3_write_addr),
                         .O2L3_write_valid(O2L3_write_valid),
                         .O2L3_pixel_out(O2L3_pixel_in), 
                         .O3L1_write_addr(O3L1_write_addr),
                         .O3L1_write_valid(O3L1_write_valid),
                         .O3L1_pixel_out(O3L1_pixel_in), 
                         .O3L2_write_addr(O3L2_write_addr),
                         .O3L2_write_valid(O3L2_write_valid),
                         .O3L2_pixel_out(O3L2_pixel_in), 
                         .O3L3_write_addr(O3L3_write_addr),
                         .O3L3_write_valid(O3L3_write_valid),
                         .O3L3_pixel_out(O3L3_pixel_in), 
                         .start_in(start_pyramid),
                         .pyramid_done(pyramid_done));

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("pyramid.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,gaussian_pyramid_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        start_pyramid = 0;

        #10
        clk_in = 1; //initialize clk (super important)
        rst_in = 1; //initialize rst (super important)
        #10
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10
        start_pyramid = 1;
        #10
        start_pyramid = 0;
        #1200000

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule //gaussian_blur_tb

`default_nettype wire
