`timescale 1ns / 1ps
`default_nettype none

module send_descriptors #(
    parameter BRAM_LENGTH = 1000,
    parameter BIT_DEPTH = 24
    ) (
  input wire clk,
  input wire rst_in,//sys_rst
  input wire img_ready,//full_image_received
  output logic tx,//uart_txd
  input wire [BIT_DEPTH-1:0] data,
  output logic [$clog2(BRAM_LENGTH)-1:0] address, // gets wired to the BRAM
  output logic busy, //or we could do img_sent whichever makes more sense
  output logic send,
  output logic [1:0] out_state,
  output logic tx_free
  );
    // states
    typedef enum {INACTIVE=0, WAITING=1, UPPER_BYTE=2, LOWER_BYTE=3, MIDDLE_BYTE=4} module_state;
    module_state state;

    always_comb begin
        case(state)
            INACTIVE : out_state = 0;
            WAITING : out_state = 1;
            UPPER_BYTE : out_state = 2;
            LOWER_BYTE : out_state = 4;
            MIDDLE_BYTE : out_state = 3;
        endcase
    end 

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
    logic [7:0] upper_byte;
    logic [7:0] middle_byte;
    logic [7:0] lower_byte;

    
    // if we have a valid_o, update pixel location for BRAM 
    always_ff @(posedge clk) begin
      if (rst_in) begin
        state <= INACTIVE;
        counter <= 0;
        pixel <= 0;
        send <= 0;
        address <= 0;
        busy <= 0;
      end else begin
        case(state)
            // before coming into INACTIVE set busy to 0
            INACTIVE: if (img_ready) begin
                state <= WAITING;
                counter <= 0;
                busy <= 1'b1;
                send <= 1'b0;
                address <= 0;
            end else begin
                state <= INACTIVE;
                busy <= 1'b0;
            end
            // before coming into WAITING set counter and address
            WAITING: if (~tx_free & send) begin
                state <= UPPER_BYTE;// sending the more significant byte first for convenience on python side
                send <= 0;
            end else if(counter==2'b10) begin
                pixel <= data[23:16];
                upper_byte <= data[23:16];
                middle_byte <= data[15:8];
                lower_byte <= data[7:0];
                send <= 1'b1;
            end else begin
                counter <= counter + 1;
                state <= WAITING;
            end
            UPPER_BYTE: if (~tx_free & send) begin 
                state <= MIDDLE_BYTE;// sending the more significant byte first for convenience on python side
                send <= 0;
            end else if (tx_free) begin
                // if we're done transmitting check what state to jump to
                // TODO(sgrg): the address counter never actually reaches 16384 
                pixel <= middle_byte;
                send <= 1'b1;
            end else begin
                state <= UPPER_BYTE;
                send <= 1'b0;
                // address <= address + 1;
            end
            MIDDLE_BYTE : if (~tx_free & send) begin 
                state <= LOWER_BYTE;// sending the more significant byte first for convenience on python side
                send <= 0;
            end else if (tx_free) begin
                // if we're done transmitting check what state to jump to
                // TODO(sgrg): the address counter never actually reaches 16384 
                pixel <= lower_byte;
                send <= 1'b1;
            end else begin
                state <= MIDDLE_BYTE;
                send <= 1'b0;
                // address <= address + 1;
            end
            // before coming into TRANSMITTING have set 
            // send to 1, pixel to data
            // wait for tx_free to go low
            LOWER_BYTE: if (tx_free) begin
                // if we're done transmitting check what state to jump to
                // TODO(sgrg): the address counter never actually reaches 16384 
                if (address == BRAM_LENGTH - 1) begin 
                    state <= INACTIVE;
                    busy <= 0;
                    send <= 0;
                end else begin
                    address<= address + 1;
                    counter <= 0;
                    state <= WAITING;
                    send <= 1'b0;
                end
            end else begin
                state <= LOWER_BYTE;
                send <= 1'b0;
                // address <= address + 1;
            end
        endcase
      end
    end
    
endmodule // send_descriptors

`default_nettype wire
