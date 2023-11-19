// Taken and partially modified from https://github.com/georgeyhere/FPGA-Video-Processing/blob/master/rtl/ps_gaussian.v

`timescale 1ns / 1ps
`default_nettype none

module gaussian #(parameter WIDTH = 8) (
                    input wire clk_in,
                    input wire rst_in,

                    input wire[WIDTH*3-1:0] r0_data_in,
                    input wire[WIDTH*3-1:0] r1_data_in,
                    input wire[WIDTH*3-1:0] r2_data_in,
                    input wire data_valid_in,

                    output logic[WIDTH-1:0] data_out,
                    output logic data_valid_out,

                    output logic error_out,
                    output logic busy_out);

    integer i;

    //  3x3 kernel
    logic [7:0] kernel [8:0];
    // KERNEL DEFINITION: 3X3 GAUSSIAN BLUR
    initial begin
        kernel[0] = 1;
        kernel[1] = 2;
        kernel[2] = 1;
        kernel[3] = 2;
        kernel[4] = 4;
        kernel[5] = 2;
        kernel[6] = 1;
        kernel[7] = 2;
        kernel[8] = 1;
    end

    // stage 1: multiply
    logic [WIDTH*9-1:0]     rowdata;
    logic [8:0]             stage1_data [WIDTH:0];
    logic                   stage1_valid;

    logic                   stage1_reg_valid;
    logic [8:0]             stage1_data_reg [WIDTH:0];
    

    // stage 2: accumulate
    logic [WIDTH+2:0]       stage2_accumulator;
    logic [WIDTH+2:0]       stage2_data;
    logic                   stage2_valid;

    // stage 3: divide by 16
    logic [WIDTH+2:0]       stage3_data;
    logic                   stage3_valid;

    // PIPELINE STAGE 1 (2 cycles)
    //
    assign rowdata = {i_r0_data, i_r1_data, i_r2_data};

    // multiply pixel data by kernel
    always_ff@(posedge clk_in) begin
        if(rst_in) begin
            stage1_valid <= 0;
            for(i=0; i<9; i=i+1) begin
                stage1_data[i] <= 0;
            end
        end
        else begin
            stage1_valid <= i_valid;
            for(i=0; i<9; i=i+1) begin
                stage1_data[i] <= $signed(kernel[i]) * 
                                  $signed({1'b0, rowdata[i*8+:8]});
            end
        end
    end

    // another register here for performance
    always_ff@(posedge clk_in) begin
        if(rst_in) begin
            stage1_reg_valid <= 0;
            for(i=0; i<9; i=i+1) begin
                stage1_data_reg[i] <= 0;
            end
        end
        else begin
            stage1_reg_valid <= stage1_valid;
            for(i=0; i<9; i=i+1) begin
                stage1_data_reg[i] <= stage1_data[i];
            end
        end
    end

    // PIPELINE STAGE 2 (1 cycle)
    //
    // sum all the stage 1 data
    always_comb begin
        stage2_accumulator = 0;
        for(i=0;  i<9; i=i+1) begin
            stage2_accumulator = $signed(stage2_accumulator) +
                                 $signed(stage1_data_reg[i]);
        end
    end

    // and register it
    always_ff@(posedge clk_in) begin
        if(rst_in) begin
            stage2_valid <= 0;
            stage2_data  <= 0;
        end
        else begin
            stage2_valid <= stage1_reg_valid;
            stage2_data  <= stage2_accumulator;
        end
    end

    // PIPELINE STAGE 3 (1 cycle)
    //
    // divide by 16 and output
    always_ff@(posedge clk_in) begin
        if(rst_in) begin
            data_valid_out <= 0;
            data_out  <= 0;
        end
        else begin
            data_valid_out <= stage2_valid;
            data_out  <= stage2_data >> 4; // stage2 is WIDTH+3 bits, output is WIDTH bits
        end
    end

endmodule

module gaussian_top #(
    parameter WIDTH=128, HEIGHT=128) (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_in,
    input wire [3:0] index_in, // index of 3x3 where top left is 0, bottom right is 8
    output logic [7:0] data_out,
    output logic data_valid_out,
    );

    always_ff@(posedge clk_in) begin
        if(rst_in) begin

        end else begin
            
        end
    end

endmodule

`default_nettype wire
