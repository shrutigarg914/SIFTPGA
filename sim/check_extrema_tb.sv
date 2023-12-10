`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"X`"
`endif  /* ! SYNTHESIS */

module check_extrema_tb;
    parameter BIT_DEPTH = 9;
    parameter DIMENSION = 64;
    logic signed [BIT_DEPTH-1:0] first_data, second_data;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address, second_address;
    // logic signed [BIT_DEPTH-1:0] first_pixel_value, second_pixel_value;
    logic [$clog2(DIMENSION)-1:0] x, y;
    logic read, rst_in, clk_in, start_checking, done_checking;
    logic first_is_extremum, second_is_extremum;
    logic [2:0] module_state;

    logic first_is_min, first_is_max;
    logic second_is_min, second_is_max; 
    // logic read;   
    logic [$clog2(DIMENSION)-1:0] read_x;
    logic [$clog2(DIMENSION)-1:0] read_y;
    logic [10:0] number_extrema;


check_extrema #(
  .DIMENSION(DIMENSION)
) finder (
  .clk(clk_in),
  .rst_in(rst_in),
  .first_data(first_data),
  .first_address(first_address),
  .second_data(second_data),
  .second_address(second_address),
  .enable(start_checking),
  .x(x),
  .y(y),
  .first_is_extremum(first_is_extremum),
  .second_is_extremum(second_is_extremum),
  .done_checking(done_checking),
  .state_number(module_state),
  .first_is_max(first_is_max),
  .first_is_min(first_is_min),
  .second_is_max(second_is_max),
  .second_is_min(second_is_min),
  .read_x(read_x),
  .read_y(read_y),
  .read(read)
  );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(9),                       // Specify RAM data width
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
        .RAM_WIDTH(9),                       // Specify RAM data width
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
        number_extrema = 0;
        #10;
        rst_in = 1'b1;
        #10;
        rst_in = 0;
        #10;
        // set start_checking to true
        start_checking = 1'b1;
        #10;
        start_checking = 1'b0;
        while (~done_checking) begin
            if (first_is_extremum) begin
                $display("Extremum in BRAM 1  (", x, ", ", y, ")");
                number_extrema = number_extrema +1'b1;
            end
            if (second_is_extremum) begin
                $display("Extremum in BRAM 2  (", x, ", ", y, ")");
                number_extrema = number_extrema +1'b1;
            end
            // $display("checked  (", x, ", ", y, ")");
            #10;
        end
        $display("found ", number_extrema, " extrema total");
        $finish;
    end

endmodule //check_extrema_tb
`default_nettype wire
