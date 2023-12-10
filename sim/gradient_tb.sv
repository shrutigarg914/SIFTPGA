`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"util/X`"
`endif  /* ! SYNTHESIS */

module gradient_tb;
    parameter BIT_DEPTH = 8;
    parameter WIDTH = 64;
    parameter HEIGHT = 64;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;

    logic [$clog2(WIDTH * HEIGHT)-1:0] read_addr;
    logic read_addr_valid;
    logic [BIT_DEPTH-1:0] pixel_in;
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] x_write_addr;
    logic x_write_valid;
    logic [BIT_DEPTH:0] x_pixel_out;
    
    logic [$clog2(WIDTH * HEIGHT)-1:0] y_write_addr;
    logic y_write_valid;
    logic [BIT_DEPTH:0] y_pixel_out;

    logic start_in;
    logic gradient_done;

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

    gradient_image gradient(.clk_in(clk_in), .rst_in(rst_in),
                         .ext_read_addr(read_addr),
                         .ext_read_addr_valid(read_addr_valid),
                         .ext_pixel_in(pixel_in),
                         .x_write_addr(x_write_addr),
                         .x_write_valid(x_write_valid),
                         .x_pixel_out(x_pixel_out), 
                         .y_write_addr(y_write_addr),
                         .y_write_valid(y_write_valid),
                         .y_pixel_out(y_pixel_out), 
                         .start_in(start_in),
                         .gradient_done(gradient_done));
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("gradient.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,gradient_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        start_in = 0;

        #10
        clk_in = 1; //initialize clk (super important)
        rst_in = 1; //initialize rst (super important)
        #10
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10
        start_in = 1;
        #10
        start_in = 0;
        #350000

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule //gradient_tb

`default_nettype wire
