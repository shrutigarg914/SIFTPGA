`timescale 1ns / 1ps
`default_nettype none

module orientation_tb;
    parameter WIDTH = 8;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [3:0] x_write_addr;
    logic x_write_valid;
    logic [7:0] x_pixel_in;
    logic [3:0] x_read_addr;
    logic x_read_addr_valid;
    logic [7:0] x_pixel_out;
    logic [3:0] y_write_addr;
    logic y_write_valid;
    logic [7:0] y_pixel_in;
    logic [3:0] y_read_addr;
    logic y_read_addr_valid;
    logic [7:0] y_pixel_out;
    logic [1:0] center_addr_x;
    logic [1:0] center_addr_y;
    logic valid_in;
    logic valid_out;
    logic [2:0] bin_out;

    // make two dual port BRAMs for x and y with 4x4 width and 8 bit depth
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(4*4))
    x_grad (
        .addra(x_write_addr),
        .clka(clk_in),
        .wea(x_write_valid),
        .dina(x_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(x_read_addr),
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(x_pixel_out)
    );
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit signed
    .RAM_DEPTH(4*4))
    y_grad (
        .addra(y_write_addr),
        .clka(clk_in),
        .wea(y_write_valid),
        .dina(y_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(y_read_addr),
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(y_pixel_out)
    );

    gradient_orientation #(
        .WIDTH(4),
        .HEIGHT(4),
        .BIT_DEPTH(8)
    )
    orientation(.clk_in(clk_in), .rst_in(rst_in),
                .x_read_addr(x_read_addr),
                .x_read_addr_valid(x_read_addr_valid),
                .x_pixel_in(x_pixel_out),
                .y_read_addr(y_read_addr),
                .y_read_addr_valid(y_read_addr_valid),
                .y_pixel_in(y_pixel_out),
                .center_addr_x(center_addr_x),
                .center_addr_y(center_addr_y),
                .valid_in(valid_in), 
                .valid_out(valid_out),
                .bin_out(bin_out),
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

        #10
        // write test cases to BRAMs
        x_pixel_in = 2;
        y_pixel_in = 1;
        x_write_addr = 0;
        y_write_addr = 0;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 1;
        y_pixel_in = 2;
        x_write_addr = 1;
        y_write_addr = 1;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -1;
        y_pixel_in = 2;
        x_write_addr = 2;
        y_write_addr = 2;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -2;
        y_pixel_in = 1;
        x_write_addr = 3;
        y_write_addr = 3;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -2;
        y_pixel_in = -1;
        x_write_addr = 4;
        y_write_addr = 4;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -1;
        y_pixel_in = -2;
        x_write_addr = 5;
        y_write_addr = 5;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 1;
        y_pixel_in = -2;
        x_write_addr = 6;
        y_write_addr = 6;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 2;
        y_pixel_in = -1;
        x_write_addr = 7;
        y_write_addr = 7;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 1;
        y_pixel_in = 0;
        x_write_addr = 8;
        y_write_addr = 8;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 1;
        y_pixel_in = 1;
        x_write_addr = 9;
        y_write_addr = 9;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 0;
        y_pixel_in = 1;
        x_write_addr = 10;
        y_write_addr = 10;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -1;
        y_pixel_in = 1;
        x_write_addr = 11;
        y_write_addr = 11;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -1;
        y_pixel_in = 0;
        x_write_addr = 12;
        y_write_addr = 12;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = -1;
        y_pixel_in = -1;
        x_write_addr = 13;
        y_write_addr = 13;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 0;
        y_pixel_in = -1;
        x_write_addr = 14;
        y_write_addr = 14;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        x_pixel_in = 1;
        y_pixel_in = -1;
        x_write_addr = 15;
        y_write_addr = 15;
        x_write_valid = 1;
        y_write_valid = 1;
        #10
        x_write_valid = 0;
        y_write_valid = 0;
        #20
        
        
        for (int i = 0; i<4; i= i+1)begin
            for (int j=0; j<4; j=j+1) begin
                center_addr_x = j;
                center_addr_y = i;
                valid_in = 1;
                #10
                valid_in = 0;
                #100
                $display("Bin ", bin_out);
            end
        end

        $display("Finishing Sim"); //print nice message
        $finish;
    end
endmodule // orientation_tb

`default_nettype wire
