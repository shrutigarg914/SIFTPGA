`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"X`"
`endif  /* ! SYNTHESIS */

module check_extrema_tb;
    parameter BIT_DEPTH = 9;
    parameter DIMENSION = 4;
    logic signed [BIT_DEPTH-1:0] first_data, second_data;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address, second_address;
    // logic signed [BIT_DEPTH-1:0] first_pixel_value, second_pixel_value;
    logic [$clog2(DIMENSION)-1:0] x, y;
    logic read, rst_in, clk_in, busy, reader_done;

check_extrema #(
  .DIMENSION(4)
) finder (
  input wire clk,
  input wire rst_in,
  // input wire have_prev,
  // input wire have_next,

  input wire signed [BIT_DEPTH-1:0] first_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address,
  
  input wire signed [BIT_DEPTH-1:0] second_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] second_address,
  
  input wire enable,
  // input wire [BIT_DEPTH-1:0] next_data,
  // input wire [$clog2(DIMENSION*DIMENSION)-1:0] next_address,
  // input wire [BIT_DEPTH-1:0] prev_data,
  // input wire [$clog2(DIMENSION*DIMENSION)-1:0] prev_address,
  output logic [$clog2(DIMENSION)-1:0] x,
  output logic [$clog2(DIMENSION)-1:0] y,
  output logic first_is_extremum,
  output logic second_is_extremum,
  output logic done_checking
  );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(9),                       // Specify RAM data width
        .RAM_DEPTH(16),                     // Specify RAM depth (number of entries)
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
        .RAM_WIDTH(9),                       // Specify RAM data width
        .RAM_DEPTH(16),                     // Specify RAM depth (number of entries)
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

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    initial begin
        $dumpfile("check_extrema.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,check_extrema_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10;
        rst_in = 1'b1;
        #10;
        rst_in = 0;
        // for x, y 0,0 to 3,3 lets read everything and check we're getting what we want
        for (int i=0; i<4; i = i +1) begin
            for (int j=0; j<4; j=j+1) begin
                x = j;
                y = i;
                #10;
                read = 1'b1;
                while (!reader_done) begin
                    #10;
                    read = 1'b0;
                end
                $display("Pixel position  (", x, ", ", y, ")");
                $display("Values:", first_data, ", ", second_data);
            end
        end
        $finish;
    end

endmodule //check_extrema_tb
`default_nettype wire
