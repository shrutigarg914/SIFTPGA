`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"X`"
`endif  /* ! SYNTHESIS */

module find_keypts_tb;
    parameter BIT_DEPTH = 8;
    parameter DIMENSION = 64;
    parameter TOP_HEIGHT = DIMENSION;
    parameter TOP_WIDTH = DIMENSION;
    logic signed [BIT_DEPTH-1:0] first_data, second_data, third_data, O2L1_data, O2L2_data, O2L3_data, O3L1_data, O3L2_data, O3L3_data;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address, second_address, third_address;
    logic [$clog2(DIMENSION / 2* DIMENSION / 2)-1:0] O2L1_read_addr, O2L2_read_addr, O2L3_read_addr;
    logic [$clog2(DIMENSION / 4* DIMENSION / 4)-1:0] O3L1_read_addr, O3L2_read_addr, O3L3_read_addr;
    logic rst_in, clk_in;
    logic [10:0] number_keypt;
    logic dog_one_done;
    
    logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] key_write_addr;
    logic key_wea, in_ocatve_3_latched;
    logic [(2*$clog2(DIMENSION)):0] keypoint_out;

    // logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1_read_addr, O1L2_read_addr, O1L3_read_addr, O1L1L2_address;
    // logic [BIT_DEPTH-1:0] O1L1_data, O1L2_data, O1L3_data;
    logic keypoints_done, start_keypt;
    // logic signed [BIT_DEPTH:0] O1L1L2_data_write;
    // logic signed [BIT_DEPTH:0] O1L1L2_data_write, ;

    find_keypoints #(.DIMENSION(DIMENSION)
    ) finder (
    .clk(clk_in),
    .rst_in(rst_in),
    .key_write_addr(key_write_addr),
    .key_wea(key_wea),
    .keypoint_out(keypoint_out),

    .O1L1_read_addr(first_address),
    .O1L1_data(first_data),

    .O1L2_read_addr(second_address),
    .O1L2_data(second_data),
    
    .O1L3_read_addr(third_address),
    .O1L3_data(third_data),

    .O2L1_read_addr(O2L1_read_addr),
    .O2L1_data(O2L1_data),

    .O2L2_read_addr(O2L2_read_addr),
    .O2L2_data(O2L2_data),
  
    .O2L3_read_addr(O2L3_read_addr),
    .O2L3_data(O2L3_data),
  
    .O3L1_read_addr(O3L1_read_addr),
    .O3L1_data(O3L1_data),

    .O3L2_read_addr(O3L2_read_addr),
    .O3L2_data(O3L2_data),
  
    .O3L3_read_addr(O3L3_read_addr),
    .O3L3_data(O3L3_data),
    
    // start and done signals
    .start(start_keypt),
    .keypoints_done(keypoints_done),

    .in_ocatve_3_latched(in_ocatve_3_latched),

    .O1_DOG_L2L3_done(dog_one_done)

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

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION /2 *DIMENSION / 2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L1_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L1_bram (
        .addra(O2L1_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L1_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION /2 *DIMENSION / 2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L2_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L2_bram (
        .addra(O2L2_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L2_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION / 2*DIMENSION / 2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L3_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L3_bram (
        .addra(O2L3_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L3_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION /4 *DIMENSION / 4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L1_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L1_bram (
        .addra(O3L1_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L1_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION /4 *DIMENSION / 4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L2_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L2_bram (
        .addra(O3L2_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L2_data)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION / 4*DIMENSION / 4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L3_test_bram.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L3_bram (
        .addra(O3L3_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L3_data)      // RAM output data, width determined from RAM_WIDTH
    );
    // assign first_address = O1L1L2_address;
    // assign second_address = O1L1L2_address;
    logic O1L1L2_wea;
    // logic [2:0] O1L1L2_state;

    // dog #(.DIMENSION(DIMENSION)) O1_DOG_L1L2 (
    // .clk(clk_in),
    // .rst_in(rst_in),//sys_rst
    // .bram_ready(start_keypt),//we can start populating this BRAM first
    // .sharper_pix(O1L1_data),
    // .fuzzier_pix(O1L2_data),
    // .done(dog_one_done),
    // .address(O1L1L2_address),
    // .data_out(O1L1L2_data_write),
    // .wea(O1L1L2_wea),
    // .state_num(O1L1L2_state)
    // );

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
        number_keypt = 0;
        #10;
        // need to low high low the start so dog will start :skull:
        start_keypt = 1'b0;
        #10;
        // set start_checking to true
        start_keypt = 1'b1;
        #10;
        start_keypt = 1'b0;

        while (~keypoints_done) begin
            if (dog_one_done) begin
                $display("DOG ONE DONE");
            end
            if (key_wea) begin
                // $display("Writing  (", keypoint_out[7:4], ", ", keypoint_out[3:1], ") in BRAM ", keypoint_out[0], ", at address ", key_write_addr);
                $display("Writing  (", keypoint_out, ", ", keypoint_out, ") in BRAM ", keypoint_out[0], ", at address ", key_write_addr);
                number_keypt = number_keypt + 1'b1;
            end
            #10;
        end
        $display("found ", number_keypt, " extrema total");
        $finish;
    end

endmodule //find_keypts_tb
`default_nettype wire
