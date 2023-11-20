`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire uart_rxd,
  input wire [3:0] btn, //all four momentary button switches
  output logic uart_txd
  );
    logic tx, rx, sys_rst;
    assign sys_rst = btn[0];
    // assign tx = uart_txd;
    assign rx = uart_rxd;

    uart_tx #(.CLOCKS_PER_BAUD(33))
    utx (
        .clk(clk_100mhz),
        .data_i(data_i),
        .start_i(start_i),
        .done_o(done_o),
        .tx(uart_txd));
        logic clk;
    logic start_i;
    logic done_o;
    logic [7:0] data_i;
    logic [7:0] pause;
    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        pause <= 0;
        start_i <= 0;
        data_i <= 0;
      end else begin
        if (pause==8'b0000_0000) begin
            data_i <= 8'd24;
            start_i<=1;
          end else begin
            start_i <= 0;
          end
        pause <= pause + 1'b1;
      end
    end
endmodule // top_level

`default_nettype wire