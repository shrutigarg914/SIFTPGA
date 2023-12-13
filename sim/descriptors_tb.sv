`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"X`"
`endif  /* ! SYNTHESIS */

module descriptors_tb;
    parameter BIT_DEPTH = 8;
    parameter DIMENSION = 64;
    parameter TOP_HEIGHT = DIMENSION;
    parameter TOP_WIDTH = DIMENSION;
    parameter PATCH_SIZE = 4;
  logic rst_in, clk_in;
  logic [$clog2(TOP_HEIGHT * TOP_WIDTH)-1:0] desc_write_addr;
  logic desc_wea;
  logic [($clog2(PATCH_SIZE/2 * PATCH_SIZE/2)+ 1)*8-1:0] desc_out;
  logic [$clog2(1000)-1:0] key_read_addr;
  logic [(2*$clog2(DIMENSION)):0] keypoint_read;
  
  logic signed [BIT_DEPTH-1:0] O1L1_x_grad, O1L1_y_grad;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L1_x_address, O1L1_y_address;
  logic signed [BIT_DEPTH-1:0] O1L2_x_grad, O1L2_y_grad;
  logic [$clog2(DIMENSION*DIMENSION)-1:0] O1L2_x_address, O1L2_y_address;
  logic signed [BIT_DEPTH-1:0] O2L1_x_grad,O2L1_y_grad;
  logic [$clog2(DIMENSION / 2*DIMENSION / 2)-1:0] O2L1_x_address, O2L1_y_address;
  logic signed [BIT_DEPTH-1:0] O2L2_x_grad, O2L2_y_grad;
  logic [$clog2(DIMENSION / 2*DIMENSION/2)-1:0] O2L2_x_address, O2L2_y_address;
  logic signed [BIT_DEPTH-1:0] O3L1_x_grad, O3L1_y_grad;
  logic [$clog2(DIMENSION /4*DIMENSION / 4)-1:0] O3L1_x_address, O3L1_y_address;
  logic signed [BIT_DEPTH-1:0] O3L2_x_grad, O3L2_y_grad;
  logic [$clog2(DIMENSION / 4*DIMENSION/4)-1:0] O3L2_x_address, O3L2_y_address;
  logic descriptors_done, start_desc;
  logic [1:0] octave;
  logic [3:0] state;
  
  generate_descriptors generator (
    .clk(clk_in),
    .rst_in(rst_in),
    // For all descriptors
    .desc_write_addr(desc_write_addr),
    .desc_wea(desc_wea),
    .desc_out(desc_out),
    .key_read_addr(key_read_addr),
    .keypoint_read(keypoint_read),
    .O1L1_x_grad(O1L1_x_grad),
    .O1L1_y_grad(O1L1_y_grad),
    .O1L1_x_address(O1L1_x_address),
    .O1L1_y_address(O1L1_y_address),
    .O1L2_x_grad(O1L2_x_grad),
    .O1L2_y_grad(O1L2_y_grad),
    .O1L2_x_address(O1L2_x_address),
    .O1L2_y_address(O1L2_y_address),
    .O2L1_x_grad(O2L1_x_grad),
    .O2L1_y_grad(O2L1_y_grad),
    .O2L1_x_address(O2L1_x_address),
    .O2L1_y_address(O2L1_y_address),
    .O2L2_x_grad(O2L2_x_grad),
    .O2L2_y_grad(O2L2_y_grad),
    .O2L2_x_address(O2L2_x_address),
    .O2L2_y_address(O2L2_y_address),
    .O3L1_x_grad(O3L1_x_grad),
    .O3L1_y_grad(O3L1_y_grad),
    .O3L1_x_address(O3L1_x_address),
    .O3L1_y_address(O3L1_y_address),
    .O3L2_x_grad(O3L2_x_grad),
    .O3L2_y_grad(O3L2_y_grad),
    .O3L2_x_address(O3L2_x_address),
    .O3L2_y_address(O3L2_y_address),
    .start(start_desc),
    .descriptors_done(descriptors_done),
    .octave_state_num(octave),
    .generic_state_num(state)
  );


    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(13),                       // Specify RAM data width
        .RAM_DEPTH(1000),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(keypoints.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) keypoints (
        .addra(key_read_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(13'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(keypoint_read)      // RAM output data, width determined from RAM_WIDTH
    );

      xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(TOP_HEIGHT * TOP_WIDTH),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O1L1_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O1L1_x (
        .addra(O1L1_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O1L1_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O1L1_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O1L1_y (
        .addra(O1L1_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O1L1_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O1L2_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O1L2_x (
        .addra(O1L2_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O1L2_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION*DIMENSION),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O1L2_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O1L2_y (
        .addra(O1L2_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O1L2_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/2*DIMENSION/2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L1_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L1_y (
        .addra(O2L1_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L1_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/2*DIMENSION/2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L1_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L1_x (
        .addra(O2L1_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L1_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/2*DIMENSION/2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L2_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L2_y (
        .addra(O2L2_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L2_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/2*DIMENSION/2),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O2L2_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O2L2_x (
        .addra(O2L2_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O2L2_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/4*DIMENSION/4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L1_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L1_y (
        .addra(O3L1_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L1_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/4*DIMENSION/4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L1_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L1_x (
        .addra(O3L1_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L1_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/4*DIMENSION/4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L2_y.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L2_y (
        .addra(O3L2_y_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L2_y_grad)      // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(DIMENSION/4*DIMENSION/4),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(O3L2_x.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) O3L2_x (
        .addra(O3L2_x_address),     // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_in),       // Clock
        .wea(1'b0),         // Write enable
        .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1'b1),   // Output register enable
        .douta(O3L2_x_grad)      // RAM output data, width determined from RAM_WIDTH
    );


    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    initial begin
        $dumpfile("descriptors.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,descriptors_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10;
        rst_in = 1'b1;
        #10;
        rst_in = 0;
        #10;
        // need to low high low the start so dog will start :skull:
        start_desc = 1'b0;
        #10;
        // set start_checking to true
        start_desc = 1'b1;
        #10;
        start_desc = 1'b0;
        while (~descriptors_done) begin
            if (desc_wea) begin
                // $display("Writing  (", keypoint_out[7:4], ", ", keypoint_out[3:1], ") in BRAM ", keypoint_out[0], ", at address ", key_write_addr);
                $display("Writing  (", desc_out, " at ", desc_write_addr);
                // number_keypt = number_keypt + 1'b1;
            end
            #10;
        end
        #100;
        // $display("found ", number_keypt, " extrema total");
        $finish;
    end



endmodule // descriptors_tb

`default_nettype wire
