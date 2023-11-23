timescale 1ns / 1ps
`default_nettype none

module send_img(
  input wire clk,
  input wire rst_in,//sys_rst
  input wire img_ready,//full_image_received
  input wire tx,//uart_txd
  input wire [7:0] data,
  input wire [14:0] address, // gets wired to the BRAM
  output logic busy //or we could do img_sent whichever makes more sense
  );
    // states
    typedef enum {INACTIVE=0, INIT=1, WAITING=2, TRANSMITTING=3} state;

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
    logic send;


    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk) begin
      if (sys_rst) begin
        address <= 0;
        counter<=0;
        state<=0;
        pixel <= 0;
        send <= 0;
      end
      else begin
        case(state)
            // before coming into INACTIVE set busy to 0
            INACTIVE: if (img_ready) begin
                state <= WAITING;
                address <= 0;
                counter <= 0;
                busy <= 1'b1;
            end else begin
                state <= INACTIVE;
                busy <= 1'b0;
            end
            // before coming into WAITING set counter and address
            WAITING: if(counter==2'b10) begin
                pixel <= data;
                send <= 1'b1;
            end else if (~tx_free) begin 
                state <= TRANSMITTING;
            end else begin
                counter <= counter + 1;
                state <= WAITING;
            end
            // before coming into TRANSMITTING have set 
            // send to 1, pixel to data
            // wait for tx_free to go low
            TRANSMITTING: if (tx_free) begin
                // if we're done transmitting check what state to jump to
                if (address + 1 == 0) begin
                    state <= INACTIVE;
                    busy <= 0;
                end else begin
                    address<= address + 1;
                    counter <= 0;
                    state <= WAITING;
                end
            end else begin
                send <= 1'b0;
                state <= TRANSMITTING;
            end
        endcase
      end
  
    
endmodule // top_level

`default_nettype wire
