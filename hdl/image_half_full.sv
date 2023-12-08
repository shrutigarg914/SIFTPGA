`timescale 1ns / 1ps
`default_nettype none

module image_half_full #( 
                    parameter BIT_DEPTH = 8,
                    parameter OLD_WIDTH = 64,
                    parameter OLD_HEIGHT = 64
                    ) (
                    input wire clk_in,
                    input wire rst_in,

                    // connect to BRAM that we are reading from
                    output logic [$clog2(OLD_WIDTH * OLD_HEIGHT)-1:0] ext_read_addr,
                    output logic ext_read_addr_valid,
                    input wire [BIT_DEPTH-1:0] ext_pixel_in,

                    // connect to BRAM that we are writing to
                    output logic [$clog2(OLD_WIDTH / 2 * OLD_HEIGHT / 2)-1:0] ext_write_addr,
                    output logic ext_write_valid,
                    output logic [BIT_DEPTH-1:0] ext_pixel_out,

                    input wire start_in, // one clock cycle signal high when starting half
                    output logic resize_done, // one clock cycle signal high when finishing half

                    // outputted for testbenching
                    output logic [$clog2(OLD_WIDTH)-1:0] old_center_addr_x_used,
                    output logic [$clog2(OLD_WIDTH)-1:0] old_center_addr_y_used
                    );

    logic [$clog2(OLD_WIDTH)-1:0] center_addr_x;
    logic [$clog2(OLD_HEIGHT)-1:0] center_addr_y;
    logic busy;
    logic resize_in_valid;
    logic [BIT_DEPTH-1:0] resize_in;
    
    logic [1:0] ext_read_addr_valid_pipe;
    always_ff @(posedge clk_in) begin
        ext_read_addr_valid_pipe[0] <= ext_read_addr_valid;
        ext_read_addr_valid_pipe[1] <= ext_read_addr_valid_pipe[0];
    end

    assign ext_read_addr = center_addr_x + center_addr_y * OLD_WIDTH;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            center_addr_x <= 0;
            center_addr_y <= 0;
            old_center_addr_x_used <= 0;
            old_center_addr_y_used <= 0;
            resize_done <= 0;
            busy <= 0;
        end else begin
            if (ext_read_addr_valid) begin
                ext_read_addr_valid <= 0;
            end
            if (resize_done) begin
                resize_done <= 0;
            end
            if (resize_in_valid) begin
                resize_in_valid <= 0;
            end
            if (start_in || busy) begin
                if (start_in || ext_read_addr_valid_pipe[1]) begin
                    if (start_in) begin
                        busy <= 1;
                    end else begin
                        resize_in_valid <= 1;
                        resize_in <= ext_pixel_in;
                        old_center_addr_x_used <= center_addr_x;
                        old_center_addr_y_used <= center_addr_y;

                        if (center_addr_x == OLD_WIDTH - 1) begin
                            if (center_addr_y == OLD_HEIGHT - 1) begin
                                resize_done <= 1;
                                busy <= 0;
                                center_addr_x <= 0;
                                center_addr_y <= 0;
                            end else begin
                                center_addr_x <= 0;
                                center_addr_y <= center_addr_y + 1;
                            end
                        end else begin
                            center_addr_x <= center_addr_x + 1;
                        end
                    end
                    ext_read_addr_valid <= 1;
                end
            end
        end
    end

    image_half #(.BIT_DEPTH(BIT_DEPTH),
                 .NEW_WIDTH(OLD_WIDTH / 2))
        downsizer(
            .clk_in(clk_in),
            .rst_in(rst_in),
            .data_in(resize_in),
            .data_x_in(old_center_addr_x_used),
            .data_y_in(old_center_addr_y_used),
            .data_valid_in(resize_in_valid),
            .data_out(ext_pixel_out),
            .data_addr_out(ext_write_addr),
            .data_valid_out(ext_write_valid),
            .done_out()
    );

endmodule

`default_nettype wire
