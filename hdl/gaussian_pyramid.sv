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
                    output logic [BIT_DEPTH-1:0] O2L1_pixel_out,

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
    .RAM_DEPTH(TOP_WIDTH*TOP_HEIGHT)) //we expect a 64*64 image with 4096 pixels total
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
    .RAM_DEPTH(TOP_WIDTH*TOP_HEIGHT)) //we expect a 64*64 image with 4096 pixels total
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
    .RAM_DEPTH(TOP_WIDTH/2*TOP_HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
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
    .RAM_DEPTH(TOP_WIDTH/2*TOP_HEIGHT/2)) //we expect a 64*64 image with 4096 pixels total
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
    .RAM_DEPTH(TOP_WIDTH/4*TOP_HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
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
    .RAM_DEPTH(TOP_WIDTH/4*TOP_HEIGHT/4)) //we expect a 64*64 image with 4096 pixels total
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
            .ext_read_addr(O1_blur_read_addr),
            .ext_read_addr_valid(O1_blur_read_addr_valid),
            .ext_pixel_in(O1_blur_pixel_in),
            .ext_write_addr(O1_blur_write_addr),
            .ext_write_valid(O1_blur_write_valid),
            .ext_pixel_out(O1_blur_pixel_out), 
            .start_in(O1_start_blurring),
            .blur_done(O1_blur_done));
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1_blur_write_addr;
    logic O1_blur_write_valid;
    logic [BIT_DEPTH-1:0] O1_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1_blur_read_addr;
    logic O1_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O1_blur_pixel_in; // for reading from bram
    logic O1_start_blurring;
    logic O1_blur_done;
    
    blur_img #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(TOP_WIDTH/2),
        .HEIGHT(TOP_HEIGHT/2))
    O2_blur(.clk_in(clk_in), .rst_in(rst_in),
            .ext_read_addr(O2_blur_read_addr),
            .ext_read_addr_valid(O2_blur_read_addr_valid),
            .ext_pixel_in(O2_blur_pixel_in),
            .ext_write_addr(O2_blur_write_addr),
            .ext_write_valid(O2_blur_write_valid),
            .ext_pixel_out(O2_blur_pixel_out), 
            .start_in(O2_start_blurring),
            .blur_done(O2_blur_done));
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2_blur_write_addr;
    logic O2_blur_write_valid;
    logic [BIT_DEPTH-1:0] O2_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2_blur_read_addr;
    logic O2_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O2_blur_pixel_in; // for reading from bram
    logic O2_start_blurring;
    logic O2_blur_done;
    
    blur_img #(
        .BIT_DEPTH(BIT_DEPTH),
        .WIDTH(TOP_WIDTH/4),
        .HEIGHT(TOP_HEIGHT/4))
    O3_blur(.clk_in(clk_in), .rst_in(rst_in),
            .ext_read_addr(O3_blur_read_addr),
            .ext_read_addr_valid(O3_blur_read_addr_valid),
            .ext_pixel_in(O3_blur_pixel_in),
            .ext_write_addr(O3_blur_write_addr),
            .ext_write_valid(O3_blur_write_valid),
            .ext_pixel_out(O3_blur_pixel_out), 
            .start_in(O3_start_blurring),
            .blur_done(O3_blur_done));
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3_blur_write_addr;
    logic O3_blur_write_valid;
    logic [BIT_DEPTH-1:0] O3_blur_pixel_out; // for writing to bram
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3_blur_read_addr;
    logic O3_blur_read_addr_valid;
    logic [BIT_DEPTH-1:0] O3_blur_pixel_in; // for reading from bram
    logic O3_start_blurring;
    logic O3_blur_done;

    image_half_full #(
        .BIT_DEPTH(BIT_DEPTH),
        .OLD_WIDTH(TOP_WIDTH),
        .OLD_HEIGHT(TOP_HEIGHT))
    O1_to_O2 (.clk_in(clk_in), .rst_in(rst_in),
                         .ext_read_addr(O1_resize_read_addr),
                         .ext_read_addr_valid(O1_resize_read_addr_valid),
                         .ext_pixel_in(O1_resize_pixel_in),
                         .ext_write_addr(O2_resize_write_addr),
                         .ext_write_valid(O2_resize_write_addr_valid),
                         .ext_pixel_out(O2_resize_pixel_out), 
                         .start_in(O12_start_resizing),
                         .resize_done(O12_resize_done),
                         .old_center_addr_x_used(),
                         .old_center_addr_y_used());
    logic [$clog2(TOP_WIDTH * TOP_HEIGHT)-1:0] O1_resize_read_addr;
    logic O1_resize_read_addr_valid;
    logic [BIT_DEPTH-1:0] O1_resize_pixel_in; // the value we read from upper layer
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2_resize_write_addr;
    logic O2_resize_write_addr_valid;
    logic [BIT_DEPTH-1:0] O2_resize_pixel_out; // the value we write to lower layer
    logic O12_start_resizing;
    logic O12_resize_done;

    image_half_full #(
        .BIT_DEPTH(BIT_DEPTH),
        .OLD_WIDTH(TOP_WIDTH/2),
        .OLD_HEIGHT(TOP_HEIGHT/2))
    O2_to_O3 (.clk_in(clk_in), .rst_in(rst_in),
                         .ext_read_addr(O2_resize_read_addr),
                         .ext_read_addr_valid(O2_resize_read_addr_valid),
                         .ext_pixel_in(O2_resize_pixel_in),
                         .ext_write_addr(O3_resize_write_addr),
                         .ext_write_valid(O3_resize_write_addr_valid),
                         .ext_pixel_out(O3_resize_pixel_out), 
                         .start_in(O23_start_resizing),
                         .resize_done(O23_resize_done),
                         .old_center_addr_x_used(),
                         .old_center_addr_y_used());
    logic [$clog2(TOP_WIDTH/2 * TOP_HEIGHT/2)-1:0] O2_resize_read_addr;
    logic O2_resize_read_addr_valid;
    logic [BIT_DEPTH-1:0] O2_resize_pixel_in; // the value we read from upper layer
    logic [$clog2(TOP_WIDTH/4 * TOP_HEIGHT/4)-1:0] O3_resize_write_addr;
    logic O3_resize_write_addr_valid;
    logic [BIT_DEPTH-1:0] O3_resize_pixel_out; // the value we write to lower layer
    logic O23_start_resizing;
    logic O23_resize_done;

    // States
    typedef enum {IDLE=0, O1L1=1, O1L2=2, O1L3=3, O2L1=4, O2L2=5, O2L3=6, O3L1=7, O3L2=8, O3L3=9} module_state;

    module_state state;

    logic ext_read_addr_valid_pipe_0;
    logic ext_read_addr_valid_pipe_1;
    always_ff @(posedge clk_in) begin
        ext_read_addr_valid_pipe_0 <= ext_read_addr_valid;
        ext_read_addr_valid_pipe_1 <= ext_read_addr_valid_pipe_0;
    end
    logic start_read_original;
    logic state_initialized;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= IDLE;
            start_read_original <= 0;
            ext_read_addr <= 0;
            ext_read_addr_valid <= 0;
            state_initialized <= 0;
            pyramid_done <= 0;
        end else begin
            if (pyramid_done) begin
                pyramid_done <= 0;
            end
            if (ext_read_addr_valid) begin
                ext_read_addr_valid <= 0;
            end
            if (start_read_original) begin
                start_read_original <= 0;
            end
            case (state)
                IDLE:
                begin
                    if (start_in) begin
                        state <= O1L1;
                        start_read_original <= 1;
                    end
                end
                O1L1:
                begin
                    // Read from original image BRAM by iterating through all addresses and reading
                    if (ext_read_addr_valid_pipe_1 || start_read_original) begin
                        if (ext_read_addr == TOP_WIDTH * TOP_HEIGHT - 1) begin
                            state <= O1L2;
                            state_initialized <= 0;
                        end else begin
                            if (ext_read_addr_valid_pipe_1) begin
                                ext_read_addr <= ext_read_addr + 1;
                            end
                            ext_read_addr_valid <= 1;
                        end
                    end
                end
                O1L2:
                begin
                    // Start O1Blur, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O1_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O1_start_blurring) begin
                            O1_start_blurring <= 0;
                        end
                        if (O1_blur_done) begin
                            state <= O1L3;
                            state_initialized <= 0;
                        end
                    end
                end
                O1L3:
                begin
                    // Start O1Blur, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O1_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O1_start_blurring) begin
                            O1_start_blurring <= 0;
                        end
                        if (O1_blur_done) begin
                            state <= O2L1;
                            state_initialized <= 0;
                        end
                    end
                end
                O2L1:
                begin
                    // Start O1_to_O2, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O12_start_resizing <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O12_start_resizing) begin
                            O12_start_resizing <= 0;
                        end
                        if (O12_resize_done) begin
                            state <= O2L2;
                            state_initialized <= 0;
                        end
                    end
                end
                O2L2:
                begin
                    // Start O2Blur, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O2_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O2_start_blurring) begin
                            O2_start_blurring <= 0;
                        end
                        if (O2_blur_done) begin
                            state <= O2L3;
                            state_initialized <= 0;
                        end
                    end
                end
                O2L3:
                begin
                    // Start O2Blur, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O2_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O2_start_blurring) begin
                            O2_start_blurring <= 0;
                        end
                        if (O2_blur_done) begin
                            state <= O3L1;
                            state_initialized <= 0;
                        end
                    end
                end
                O3L1:
                begin
                    // Start O2_to_O3, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O23_start_resizing <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O23_start_resizing) begin
                            O23_start_resizing <= 0;
                        end
                        if (O23_resize_done) begin
                            state <= O3L2;
                            state_initialized <= 0;
                        end
                    end
                end
                O3L2:
                begin
                    // Start O3Blur, wait for it to be done, go next state
                    if (!state_initialized) begin
                        O3_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O3_start_blurring) begin
                            O3_start_blurring <= 0;
                        end
                        if (O3_blur_done) begin
                            state <= O3L3;
                            state_initialized <= 0;
                        end
                    end
                end
                O3L3:
                begin
                    // Start O3Blur, wait for it to be done, go back to IDLE
                    if (!state_initialized) begin
                        O3_start_blurring <= 1;
                        state_initialized <= 1;
                    end else begin
                        if (O3_start_blurring) begin
                            O3_start_blurring <= 0;
                        end
                        if (O3_blur_done) begin
                            state <= IDLE;
                            state_initialized <= 0;
                            pyramid_done <= 1;
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        O1Buffer1_write_addr = (state == O1L1) ? ext_read_addr : ((state == O1L3) ? O1_blur_write_addr : 0);
        O1Buffer1_write_valid = (state == O1L1) ? ext_read_addr_valid_pipe_1 : ((state == O1L3) ? O1_blur_write_valid : 0);
        O1Buffer1_pixel_in = (state == O1L1) ? ext_pixel_in : ((state == O1L3) ? O1_blur_pixel_out : 0);
    end
    
    always_comb begin
        O1L1_write_addr = (state == O1L1) ? ext_read_addr : 0;
        O1L1_write_valid = (state == O1L1) ? ext_read_addr_valid_pipe_1 : 0;
        O1L1_pixel_out = (state == O1L1) ? ext_pixel_in : 0;
    end
    
    always_comb begin
        O1Buffer1_read_addr = (state == O1L2) ? O1_blur_read_addr : ((state == O2L1) ? O1_resize_read_addr : 0);
        O1Buffer1_read_addr_valid = (state == O1L2) ? O1_blur_read_addr_valid : ((state == O2L1) ? O1_resize_read_addr_valid : 0);
    end

    always_comb begin
        O1_blur_pixel_in = (state == O1L2) ? O1Buffer1_pixel_out : ((state == O1L3) ? O1Buffer2_pixel_out : 0);
    end

    always_comb begin
        O1Buffer2_write_addr = (state == O1L2) ? O1_blur_write_addr : 0;
        O1Buffer2_write_valid = (state == O1L2) ? O1_blur_write_valid : 0;
        O1Buffer2_pixel_in = (state == O1L2) ? O1_blur_pixel_out : 0;
    end

    always_comb begin
        O1L2_write_addr = (state == O1L2) ? O1_blur_write_addr : 0;
        O1L2_write_valid = (state == O1L2) ? O1_blur_write_valid : 0;
        O1L2_pixel_out = (state == O1L2) ? O1_blur_pixel_out : 0;
    end

    always_comb begin
        O1Buffer2_read_addr = (state == O1L3) ? O1_blur_read_addr : 0;
        O1Buffer2_read_addr_valid = (state == O1L3) ? O1_blur_read_addr_valid : 0;
    end

    always_comb begin
        O1L3_write_addr = (state == O1L3) ? O1_blur_write_addr : 0;
        O1L3_write_valid = (state == O1L3) ? O1_blur_write_valid : 0;
        O1L3_pixel_out = (state == O1L3) ? O1_blur_pixel_out : 0;
    end

    always_comb begin
        O1_resize_pixel_in = (state == O2L1) ? O1Buffer1_pixel_out : 0;
    end

    always_comb begin
        O2Buffer1_write_addr = (state == O2L1) ? O2_resize_write_addr : ((state == O2L3) ? O2_blur_write_addr : 0);
        O2Buffer1_write_valid = (state == O2L1) ? O2_resize_write_addr_valid : ((state == O2L3) ? O2_blur_write_valid : 0);
        O2Buffer1_pixel_in = (state == O2L1) ? O2_resize_pixel_out : ((state == O2L3) ? O2_blur_pixel_out : 0);
    end

    always_comb begin
        O2L1_write_addr = (state == O2L1) ? O2_resize_write_addr : 0;
        O2L1_write_valid = (state == O2L1) ? O2_resize_write_addr_valid : 0;
        O2L1_pixel_out = (state == O2L1) ? O2_resize_pixel_out : 0;
    end

    always_comb begin
        O2Buffer1_read_addr = (state == O2L2) ? O2_blur_read_addr : ((state == O3L1) ? O2_resize_read_addr : 0);
        O2Buffer1_read_addr_valid = (state == O2L2) ? O2_blur_read_addr_valid : ((state == O3L1) ? O2_resize_read_addr_valid : 0);
    end

    always_comb begin
        O2_blur_pixel_in = (state == O2L2) ? O2Buffer1_pixel_out : ((state == O2L3) ? O2Buffer2_pixel_out : 0);
    end

    always_comb begin
        O2Buffer2_write_addr = (state == O2L2) ? O2_blur_write_addr : 0;
        O2Buffer2_write_valid = (state == O2L2) ? O2_blur_write_valid : 0;
        O2Buffer2_pixel_in = (state == O2L2) ? O2_blur_pixel_out : 0;
    end

    always_comb begin
        O2L2_write_addr = (state == O2L2) ? O2_blur_write_addr : 0;
        O2L2_write_valid = (state == O2L2) ? O2_blur_write_valid : 0;
        O2L2_pixel_out = (state == O2L2) ? O2_blur_pixel_out : 0;
    end

    always_comb begin
        O2Buffer2_read_addr = (state == O2L3) ? O2_blur_read_addr : 0;
        O2Buffer2_read_addr_valid = (state == O2L3) ? O2_blur_read_addr_valid : 0;
    end

    always_comb begin
        O2L3_write_addr = (state == O2L3) ? O2_blur_write_addr : 0;
        O2L3_write_valid = (state == O2L3) ? O2_blur_write_valid : 0;
        O2L3_pixel_out = (state == O2L3) ? O2_blur_pixel_out : 0;
    end

    always_comb begin
        O2_resize_pixel_in = (state == O3L1) ? O2Buffer1_pixel_out : 0;
    end

    always_comb begin
        O3Buffer1_write_addr = (state == O3L1) ? O3_resize_write_addr : ((state == O3L3) ? O3_blur_write_addr : 0);
        O3Buffer1_write_valid = (state == O3L1) ? O3_resize_write_addr_valid : ((state == O3L3) ? O3_blur_write_valid : 0);
        O3Buffer1_pixel_in = (state == O3L1) ? O3_resize_pixel_out : ((state == O3L3) ? O3_blur_pixel_out : 0);
    end

    always_comb begin
        O3L1_write_addr = (state == O3L1) ? O3_resize_write_addr : 0;
        O3L1_write_valid = (state == O3L1) ? O3_resize_write_addr_valid : 0;
        O3L1_pixel_out = (state == O3L1) ? O3_resize_pixel_out : 0;
    end

    always_comb begin
        O3Buffer1_read_addr = (state == O3L2) ? O3_blur_read_addr : 0;
        O3Buffer1_read_addr_valid = (state == O3L2) ? O3_blur_read_addr_valid : 0;
    end

    always_comb begin
        O3_blur_pixel_in = (state == O3L2) ? O3Buffer1_pixel_out : ((state == O3L3) ? O3Buffer2_pixel_out : 0);
    end

    always_comb begin
        O3Buffer2_write_addr = (state == O3L2) ? O3_blur_write_addr : 0;
        O3Buffer2_write_valid = (state == O3L2) ? O3_blur_write_valid : 0;
        O3Buffer2_pixel_in = (state == O3L2) ? O3_blur_pixel_out : 0;
    end

    always_comb begin
        O3L2_write_addr = (state == O3L2) ? O3_blur_write_addr : 0;
        O3L2_write_valid = (state == O3L2) ? O3_blur_write_valid : 0;
        O3L2_pixel_out = (state == O3L2) ? O3_blur_pixel_out : 0;
    end

    always_comb begin
        O3Buffer2_read_addr = (state == O3L3) ? O3_blur_read_addr : 0;
        O3Buffer2_read_addr_valid = (state == O3L3) ? O3_blur_read_addr_valid : 0;
    end

    always_comb begin
        O3L3_write_addr = (state == O3L3) ? O3_blur_write_addr : 0;
        O3L3_write_valid = (state == O3L3) ? O3_blur_write_valid : 0;
        O3L3_pixel_out = (state == O3L3) ? O3_blur_pixel_out : 0;
    end

endmodule

`default_nettype wire
