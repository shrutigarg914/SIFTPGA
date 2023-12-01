`timescale 1ns / 1ps
`default_nettype none

// Assuming 3 Octaves, 3 images per octave
module gaussian_pyramid #(
                    parameter BIT_DEPTH = 8,
                    parameter TOP_WIDTH = 64,
                    parameter TOP_HEIGHT = 64
                    ) (
                    input wire clk_in,
                    input wire rst_in,

                    // inputs from original image BRAM
                    output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] ext_read_addr,
                    output logic ext_read_addr_valid,
                    input wire [BIT_DEPTH-1:0] ext_pixel_in,

                    // all outputs to BRAMs
                    // Octave 1
                    output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L1_write_addr,
                    output logic O1L1_write_valid,
                    output logic [BIT_DEPTH-1:0] O1L1_pixel_out,

                    output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L2_write_addr,
                    output logic O1L2_write_valid,
                    output logic [BIT_DEPTH-1:0] O1L2_pixel_out,
                    
                    output logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1L3_write_addr,
                    output logic O1L3_write_valid,
                    output logic [BIT_DEPTH-1:0] O1L3_pixel_out,
                    
                    // Octave 2
                    output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L1_write_addr,
                    output logic O2L1_write_valid,
                    output logic [BIT_DEPTH-1:0] O1L1_pixel_out,

                    output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L2_write_addr,
                    output logic O2L2_write_valid,
                    output logic [BIT_DEPTH-1:0] O2L2_pixel_out,
                    
                    output logic [$clog2(TOP_WIDTH / 2 * TOP_HEIGHT / 2)-1:0] O2L3_write_addr,
                    output logic O2L3_write_valid,
                    output logic [BIT_DEPTH-1:0] O2L3_pixel_out,
                    
                    // Octave 3
                    output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L1_write_addr,
                    output logic O3L1_write_valid,
                    output logic [BIT_DEPTH-1:0] O3L1_pixel_out,

                    output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L2_write_addr,
                    output logic O3L2_write_valid,
                    output logic [BIT_DEPTH-1:0] O3L2_pixel_out,
                    
                    output logic [$clog2(TOP_WIDTH / 4 * TOP_HEIGHT / 4)-1:0] O3L3_write_addr,
                    output logic O3L3_write_valid,
                    output logic [BIT_DEPTH-1:0] O3L3_pixel_out,

                    // start and done signals
                    input wire start_in,
                    output logic pyramid_done
                    );
    // NOTE: the naming scheme sucks but its pixel_out for writing OUT of the pyramid module,
    // but pixel_in when writing IN to an intermediate BRAM

    // 2 intermediate BRAMs per octave
    // Octave 1
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH*TOP_HEIGHT)) //we expect a 64*64 image with 16384 pixels total
    O1Buffer1 (
        .addra(O1Buffer1_write_addr),
        .clka(clk_in),
        .wea(O1Buffer1_write_valid),
        .dina(O1Buffer1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O1Buffer1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O1Buffer1_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O1Buffer1_pixel_out)
    );
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1Buffer1_write_addr;
    logic O1Buffer1_write_valid;
    logic [BIT_DEPTH-1:0] O1Buffer1_pixel_in;
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1Buffer1_read_addr;
    logic O1Buffer1_read_addr_valid;
    logic [BIT_DEPTH-1:0] O1Buffer1_pixel_out;
    
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH*TOP_HEIGHT)) //we expect a 64*64 image with 16384 pixels total
    O1Buffer2 (
        .addra(O1Buffer2_write_addr),
        .clka(clk_in),
        .wea(O1Buffer2_write_valid),
        .dina(O1Buffer2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O1Buffer2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O1Buffer2_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O1Buffer2_pixel_out)
    );
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1Buffer2_write_addr;
    logic O1Buffer2_write_valid;
    logic [BIT_DEPTH-1:0] O1Buffer2_pixel_in;
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1Buffer2_read_addr;
    logic O1Buffer2_read_addr_valid;
    logic [BIT_DEPTH-1:0] O1Buffer2_pixel_out;
    
    // Octave 2
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH/2*TOP_HEIGHT/2)) //we expect a 64*64 image with 16384 pixels total
    O2Buffer1 (
        .addra(O2Buffer1_write_addr),
        .clka(clk_in),
        .wea(O2Buffer1_write_valid),
        .dina(O2Buffer1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O2Buffer1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O2Buffer1_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O2Buffer1_pixel_out)
    );
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2Buffer1_write_addr;
    logic O2Buffer1_write_valid;
    logic [BIT_DEPTH-1:0] O2Buffer1_pixel_in;
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2Buffer1_read_addr;
    logic O2Buffer1_read_addr_valid;
    logic [BIT_DEPTH-1:0] O2Buffer1_pixel_out;
    
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH/2*TOP_HEIGHT/2T)) //we expect a 64*64 image with 16384 pixels total
    O2Buffer2 (
        .addra(O2Buffer2_write_addr),
        .clka(clk_in),
        .wea(O2Buffer2_write_valid),
        .dina(O2Buffer2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O2Buffer2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O2Buffer2_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O2Buffer2_pixel_out)
    );
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2Buffer2_write_addr;
    logic O2Buffer2_write_valid;
    logic [BIT_DEPTH-1:0] O2Buffer2_pixel_in;
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2Buffer2_read_addr;
    logic O2Buffer2_read_addr_valid;
    logic [BIT_DEPTH-1:0] O2Buffer2_pixel_out;
    
    // Octave 3
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH/4*TOP_HEIGHT/4)) //we expect a 64*64 image with 16384 pixels total
    O3Buffer1 (
        .addra(O3Buffer1_write_addr),
        .clka(clk_in),
        .wea(O3Buffer1_write_valid),
        .dina(O3Buffer1_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O3Buffer1_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O3Buffer1_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O3Buffer1_pixel_out)
    );
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3Buffer1_write_addr;
    logic O3Buffer1_write_valid;
    logic [BIT_DEPTH-1:0] O3Buffer1_pixel_in;
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3Buffer1_read_addr;
    logic O3Buffer1_read_addr_valid;
    logic [BIT_DEPTH-1:0] O3Buffer1_pixel_out;
    
    xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8), // we expect 8 bit greyscale images
    .RAM_DEPTH(TOP_WIDTH/4*TOP_HEIGHT/4)) //we expect a 64*64 image with 16384 pixels total
    O3Buffer2 (
        .addra(O3Buffer2_write_addr),
        .clka(clk_in),
        .wea(O3Buffer2_write_valid),
        .dina(O3Buffer2_pixel_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(O3Buffer2_read_addr),// transformed lookup pixel
        .dinb(),
        .clkb(clk_in),
        .web(1'b0),
        .enb(O3Buffer2_read_addr_valid),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(O3Buffer2_pixel_out)
    );
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3Buffer2_write_addr;
    logic O3Buffer2_write_valid;
    logic [BIT_DEPTH-1:0] O3Buffer2_pixel_in;
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3Buffer2_read_addr;
    logic O3Buffer2_read_addr_valid;
    logic [BIT_DEPTH-1:0] O3Buffer2_pixel_out;

    // Submodules (blur_img, image resize)
    blur_img #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(TOP_WIDTH),
        .HEIGHT(TOP_HEIGHT))
    O1_blur(.clk_in(clk_in), .rst_in(rst_in),
            .ext_read_addr(read_addr),
            .ext_read_addr_valid(read_addr_valid),
            .ext_pixel_in(pixel_in),
            .ext_write_addr(O1_blur_write_addr),
            .ext_write_valid(O1_blur_write_valid),
            .ext_pixel_out(O1_blur_pixel_out), 
            .start_in(start_blurring),
            .blur_done(blur_done));
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1_blur_write_addr;
    logic O1_blur_write_valid;
    logic [BIT_DEPTH-1:0] O1_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1_blur_read_addr;
    logic O1_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O1_blur_pixel_in; // for reading from bram
    
    blur_img #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(TOP_WIDTH),
        .HEIGHT(TOP_HEIGHT))
    O2_blur(.clk_in(clk_in), .rst_in(rst_in),
            .ext_read_addr(read_addr),
            .ext_read_addr_valid(read_addr_valid),
            .ext_pixel_in(pixel_in),
            .ext_write_addr(O2_blur_write_addr),
            .ext_write_valid(O2_blur_write_valid),
            .ext_pixel_out(O2_blur_pixel_out), 
            .start_in(start_blurring),
            .blur_done(blur_done));
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O2_blur_write_addr;
    logic O2_blur_write_valid;
    logic [BIT_DEPTH-1:0] O2_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O2_blur_read_addr;
    logic O2_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O2_blur_pixel_in; // for reading from bram
    
    blur_img #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(TOP_WIDTH),
        .HEIGHT(TOP_HEIGHT))
    O3_blur(.clk_in(clk_in), .rst_in(rst_in),
            .ext_read_addr(read_addr),
            .ext_read_addr_valid(read_addr_valid),
            .ext_pixel_in(pixel_in),
            .ext_write_addr(O3_blur_write_addr),
            .ext_write_valid(O3_blur_write_valid),
            .ext_pixel_out(O3_blur_pixel_out), 
            .start_in(start_blurring),
            .blur_done(blur_done));
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O3_blur_write_addr;
    logic O3_blur_write_valid;
    logic [BIT_DEPTH-1:0] O3_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O3_blur_read_addr;
    logic O3_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O3_blur_pixel_in; // for reading from bram

    image_half #(.BIT_DEPTH(BIT_DEPTH),
                 .NEW_WIDTH(TOP_WIDTH / 2))
        O1_to_O2(
            .clk_in(clk_in),
            .rst_in(sys_rst),
            .data_in(rx_data),
            .data_x_in(center_addr_x),
            .data_y_in(center_addr_y),
            .data_valid_in(valid_o),
            .data_out(resize_out),
            .data_addr_out(resize_out_addr),
            .data_valid_out(resize_out_valid),
            .done_out()
    );

    // States
    typedef enum {IDLE=0, O1L1=1, O1L2=2, O1L3=3, O2L1=4, O2L2=5, O2L3=6, O3L1=7, O3L2=8, O3L3=9} module_state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
        end else begin
        end
    end

endmodule

`default_nettype wire
