`timescale 1ns / 1ps
`default_nettype none

module send_img #(
    parameter BRAM_LENGTH = 64 * 64
    ) (
  input wire clk,
  input wire rst_in,//sys_rst
  input wire img_ready,//full_image_received
  input wire tx,//uart_txd
  input wire [7:0] data,
  output logic [13:0] address, // gets wired to the BRAM
  output logic busy, //or we could do img_sent whichever makes more sense
  output logic send,
  output logic [1:0] out_state,
  output logic tx_free
  );
    // states
    typedef enum {INACTIVE=0, WAITING=1, TRANSMITTING=2} module_state;
    module_state state;

    // instantiating uart_tx
    // send should be a 1 cycle signal high between WAIT -> TRANSMITTING transition edge
    uart_tx #(.CLOCKS_PER_BAUD(50))
        utx (
        .clk(clk),
        .data_i(pixel),
        .start_i(send),
        .done_o(tx_free),
        .tx(tx));
    
    logic [3:0] counter;
    // logic send;
    // logic tx_free;
    logic [7:0] pixel;

    
    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk) begin
      if (rst_in) begin
        state <= INACTIVE;
        counter <= 0;
        pixel <= 0;
        send <= 0;
        address <= 0;
        out_state <= 0;
        busy <= 0;
      end else begin
        case(state)
            // before coming into INACTIVE set busy to 0
            INACTIVE: if (img_ready) begin
                state <= WAITING;
                counter <= 0;
                busy <= 1'b1;
                out_state <= 1'b1;
                send <= 1'b0;
                address <= 0;
            end else begin
                state <= INACTIVE;
                busy <= 1'b0;
                out_state <= 0;
            end
            
            // before coming into WAITING set counter and address
            WAITING: if (~tx_free & send) begin 
                out_state <= 2'b10;
                state <= TRANSMITTING;
                send <= 0;
            end else if(counter==2'b10) begin
                pixel <= data;
                send <= 1'b1;
            end else begin
                counter <= counter + 1;
                out_state <= 1'b1;
                state <= WAITING;
            end
            // before coming into TRANSMITTING have set 
            // send to 1, pixel to data
            // wait for tx_free to go low
            TRANSMITTING: if (tx_free) begin
                // if we're done transmitting check what state to jump to
                // TODO(sgrg): the address counter never actually reaches 16384 
                if (address == BRAM_LENGTH - 1) begin 
                    state <= INACTIVE;
                    out_state<=1'b0;
                    busy <= 0;
                    send <= 0;
                end else begin
                    address<= address + 1;
                    counter <= 0;
                    state <= WAITING;
                    out_state <= 1'b1;
                    send <= 1'b0;
                end
            end else begin
                state <= TRANSMITTING;
                out_state <= 2'b10;
                send <= 1'b0;
                // address <= address + 1;
            end
        endcase
      end
    end
    
endmodule // top_level

`default_nettype wire
