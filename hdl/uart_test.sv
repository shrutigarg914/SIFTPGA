`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire [15:0] sw, //all 16 input slide switches
  input wire clk_100mhz,
  input wire uart_rxd,
  input wire [3:0] btn, //all four momentary button switches
  output logic uart_txd
  );
    logic tx, rx, sys_rst;
    assign sys_rst = btn[0];
    // assign tx = uart_txd;
    assign rx = uart_rxd;
    
    logic start_i;
    logic done_o;
    logic [7:0] data_i;
    assign data_i = sw[7:0];
    assign start_i = btn_edge;
    // logic [7:0] pause;
  
  logic btn_pulse;
  logic old_btn_pulse;
  logic btn_edge;
  debouncer btn1_db(.clk_in(clk_100mhz),
                  .rst_in(sys_rst),
                  .dirty_in(btn[1]),
                  .clean_out(btn_pulse));
 
  /* this should go high for one cycle on the
  * rising edge of the (debounced) button output
  */ 
  /* TODO: write your edge detector for part 1 of the
   * lab here!
   */
  always_ff @(posedge clk_100mhz) begin
    if (btn_pulse==old_btn_pulse) begin
      btn_edge <= 1'b0;
    end else begin
      old_btn_pulse <= btn_pulse;
      btn_edge <= btn_pulse;
    end
    // if (sys_rst) begin
    //   btn_edge <= 0;
    // end else if (new_data) begin
    //   received <= spi_rx_data;
    // end
  end

  uart_tx #(.CLOCKS_PER_BAUD(33))
     utx (
        .clk(clk_100mhz),
        .data_i(data_i),
        .start_i(start_i),
        .done_o(done_o),
        .tx(uart_txd));

    // use switches+buttons
    // always_ff @(posedge clk_100mhz) begin
    //   if (~pause==8'b0000_0000) begin
    //       data_i <= 8'h24;
    //       start_i<=1;
    //     end else begin
    //       start_i <= 0;
    //     end
    //   pause <= pause + 1'b1;
    // end
endmodule // top_level

`default_nettype wire
