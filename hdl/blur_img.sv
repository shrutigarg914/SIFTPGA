`timescale 1ns / 1ps
`default_nettype none

module blur_img #(
    parameter BIT_DEPTH = 8,
    parameter WIDTH = 64,
    parameter HEIGHT = 64
    ) (
    input wire clk_in,
    input wire rst_in,

    // connect to BRAM that we are reading from
    output logic [$clog2(WIDTH * HEIGHT)-1:0] ext_read_addr,
    output logic ext_read_addr_valid,
    input wire [BIT_DEPTH-1:0] ext_pixel_in,

    // connect to BRAM that we are writing to
    output logic [$clog2(WIDTH * HEIGHT)-1:0] ext_write_addr,
    output logic ext_write_valid,
    output logic [BIT_DEPTH-1:0] ext_pixel_out,

    input wire start_in, // one clock cycle signal high when starting blur
    output logic blur_done, // one clock cycle signal high when finishing blur

    // temp outputs for tb
    output logic blur_data_valid_out,
    output logic [3:0] kernel_ind
    );
    
    logic [$clog2(WIDTH)-1:0] center_addr_x;
    logic [$clog2(HEIGHT)-1:0] center_addr_y;
    logic [$clog2(WIDTH)-1:0] center_addr_x_prev;
    logic [$clog2(HEIGHT)-1:0] center_addr_y_prev;
    // logic [3:0] kernel_ind;
    logic [3:0] kernel_ind_pipe [1:0];
    logic[BIT_DEPTH*3-1:0] row1;
    logic[BIT_DEPTH*3-1:0] row2;
    logic[BIT_DEPTH*3-1:0] row3;
    logic blur_data_valid_in;
    logic[BIT_DEPTH-1:0] blur_out;
    // logic blur_data_valid_out;
    logic busy;

    logic [1:0] ext_read_addr_valid_pipe;
    always_ff @(posedge clk_in) begin
        ext_read_addr_valid_pipe[0] <= ext_read_addr_valid;
        ext_read_addr_valid_pipe[1] <= ext_read_addr_valid_pipe[0];

        kernel_ind_pipe[0] <= kernel_ind;
        kernel_ind_pipe[1] <= kernel_ind_pipe[0];
    end

    initial begin
        center_addr_x = 0;
        center_addr_y = 0;
        blur_data_valid_in = 0;
        row1 = 0;
        row2 = 0;
        row3 = 0;
        kernel_ind = 0;
        blur_done = 0;
        busy = 0;
    end
    

    gaussian #(
        .WIDTH(BIT_DEPTH))
        blur (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .r0_data_in(row1),
        .r1_data_in(row2),
        .r2_data_in(row3),
        .data_valid_in(blur_data_valid_in),
        .data_out(blur_out),
        .data_valid_out(blur_data_valid_out),
        .error_out(),
        .busy_out()
    );

    assign ext_write_addr = center_addr_x_prev + center_addr_y_prev * WIDTH;
    assign ext_write_valid = blur_data_valid_out;
    assign ext_pixel_out = blur_out;

    // 3 stage pipeline, collect rows, do blur, write to BRAM
    always_ff @(posedge clk_in) begin
      if (rst_in) begin
        center_addr_x <= 0;
        center_addr_y <= 0;
        center_addr_x_prev <= 0;
        center_addr_y_prev <= 0;
        blur_data_valid_in <= 0;
        kernel_ind <= 0;
        blur_done <= 0;
        busy <= 0;
      end else begin
        if (ext_read_addr_valid) begin
            ext_read_addr_valid <= 0;
        end
        if (blur_data_valid_in) begin
            blur_data_valid_in <= 0;
        end
        if (busy || start_in) begin
            // we either just started the blurring part or we just finished reading the last pixel from the BRAM
            if (ext_read_addr_valid_pipe[1] || start_in) begin 
                if (!start_in) begin
                    // write the previous read result to correct row
                    case (kernel_ind_pipe[1]) // use the index from when we started reading because we've changed it by now
                        0: row1[BIT_DEPTH*3-1:BIT_DEPTH*2] <= ext_pixel_in;
                        1: row1[BIT_DEPTH*2-1:BIT_DEPTH] <= ext_pixel_in;
                        2: row1[BIT_DEPTH-1:0] <= ext_pixel_in;
                        3: row2[BIT_DEPTH*3-1:BIT_DEPTH*2] <= ext_pixel_in;
                        4: row2[BIT_DEPTH*2-1:BIT_DEPTH] <= ext_pixel_in;
                        5: row2[BIT_DEPTH-1:0] <= ext_pixel_in;
                        6: row3[BIT_DEPTH*3-1:BIT_DEPTH*2] <= ext_pixel_in;
                        7: row3[BIT_DEPTH*2-1:BIT_DEPTH] <= ext_pixel_in;
                        8: row3[BIT_DEPTH-1:0] <= ext_pixel_in;
                    endcase
                end else begin
                    busy <= 1;
                end

                // update read pixel addr based on current center and kernel_ind
                case (kernel_ind)
                0:
                    ext_read_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * WIDTH;
                1:
                    ext_read_addr <= center_addr_x 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * WIDTH;
                2:
                    ext_read_addr <= ((center_addr_x == WIDTH - 1) ? center_addr_x : center_addr_x + 1) 
                                        + ((center_addr_y == 0) ? center_addr_y : center_addr_y - 1) * WIDTH;
                3:
                    ext_read_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + center_addr_y * WIDTH;
                4:
                    ext_read_addr <= center_addr_x 
                                        + center_addr_y * WIDTH;
                5:
                    ext_read_addr <= ((center_addr_x == WIDTH - 1) ? center_addr_x : center_addr_x + 1) 
                                        + center_addr_y * WIDTH;
                6:
                    ext_read_addr <= ((center_addr_x == 0) ? center_addr_x : center_addr_x - 1) 
                                        + ((center_addr_y == HEIGHT - 1) ? center_addr_y : center_addr_y + 1) * WIDTH;
                7:
                    ext_read_addr <= center_addr_x 
                                        + ((center_addr_y == HEIGHT - 1) ? center_addr_y : center_addr_y + 1) * WIDTH;
                8:
                    ext_read_addr <= ((center_addr_x == WIDTH - 1) ? center_addr_x : center_addr_x + 1) 
                                        + ((center_addr_y == HEIGHT - 1) ? center_addr_y : center_addr_y + 1) * WIDTH;
                endcase
                ext_read_addr_valid <= 1;

                // update kernel_ind
                if (kernel_ind == 8) begin
                    blur_data_valid_in <= 1; // start blur module (just finished collecting rows)
                    // reset kernel_ind and go to next pixel (inc center x, y)
                    kernel_ind <= 0;
                    center_addr_x_prev <= center_addr_x;
                    center_addr_y_prev <= center_addr_y;
                    if (center_addr_x == WIDTH - 1) begin
                        if (center_addr_y == HEIGHT - 1) begin
                            blur_done <= 1;
                            busy <= 0;
                        end else begin
                            center_addr_x <= 0;
                            center_addr_y <= center_addr_y + 1;
                        end
                    end else begin
                        center_addr_x <= center_addr_x + 1;
                    end
                end else begin
                    kernel_ind <= kernel_ind + 1;
                end
            end

        end
      end
    end

endmodule

`default_nettype wire
