`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"X`"
`endif  /* ! SYNTHESIS */

module find_keypts_tb;
    parameter BIT_DEPTH = 8;
    parameter DIMENSION = 4;
    parameter TOP_HEIGHT = DIMENSION;
    parameter TOP_WIDTH = DIMENSION;
    logic signed [BIT_DEPTH-1:0] first_data, second_data, third_data;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address, second_address, third_address;
    logic rst_in, clk_in;
    logic [10:0] number_keypt;
    
    logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] O1key_write_addr;
    logic O1key_wea;
    logic [(2*$clog2(DIMENSION)):0] O1_keypoint_out;

    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1_read_addr, O1L2_read_addr, O1L3_read_addr;
    logic [BIT_DEPTH-1:0] O1L1_data, O1L2_data, O1L3_data;
    logic keypoints_done, start_keypt;

    find_keypoints #(.DIMENSION(DIMENSION)
    ) finder (
    .clk(clk_in),
    .rst_in(rst_in),
    .O1key_write_addr(O1key_write_addr),
    .O1key_wea(O1key_wea),
    .O1_keypoint_out(O1_keypoint_out),

    .O1L1_read_addr(first_address),
    .O1L1_data(first_data),

    .O1L2_read_addr(second_address),
    .O1L2_data(second_data),
    
    .O1L3_read_addr(third_address),
    .O1L3_data(third_data),
    
    // start and done signals
    .start(start_keypt),
    .keypoints_done(keypoints_done)

    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(first_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) first_bram (
        .addra(first_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(first_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(second_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) second_bram (
        .addra(second_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(second_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(third_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) third_bram (
        .addra(third_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(third_data)      // RAM output data, width determined from RAM_WIDTH
    );

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    initial begin
        $dumpfile("find_keypt.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,find_keypts_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10;
        rst_in = 1'b1;
        #10;
        rst_in = 0;
        #10;
        // set start_checking to true
        start_keypt = 1'b1;
        #10;
        start_keypt = 1'b0;
        while (~keypoints_done) begin
            if (O1key_wea) begin
                $display("Writing  ", O1_keypoint_out, ", at address ", O1key_write_addr);
                number_keypt = number_keypt +1'b1;
            end
            // $display("checked  (", x, ", ", y, ")");
            #10;
        end
        $display("found ", number_keypt, " extrema total");
        $finish;
    end

endmodule //find_keypts_tb
`default_nettype wire
