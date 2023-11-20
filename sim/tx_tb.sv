`timescale 1ns / 1ps
`default_nettype none

module tx_tb;

    logic clk;
    logic [7:0] data_i;
    logic start_i;
    reg done_o;
    reg tx;
    //make logics for inputs and outputs!
    // corresponding to 300k Baudrate at 100MHz clock frequency
    uart_tx #(.CLOCKS_PER_BAUD(33))
     utx (
        .clk(clk),
        .data_i(data_i),
        .start_i(start_i),
        .done_o(done_o),
        .tx(tx));

    always begin
        #5;  // every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk = !clk;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("tx.vcd"); //file to store value change dump (vcd)
        $dumpvars(0, tx_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk = 0; //initialize clk (super important)
        #100;  //wait a little bit of time at beginning
        data_i = 8'b0101_0100;
        start_i = 1;
        #10;
        // start_i = 0;
        while (!done_o) begin
            #10;
            data_i = 8'b1111_1111;
            // $display("%b    %b", done_o, data_i);
        end
        #10;
        // start_i = 1;
        #10;
        start_i = 0;
        while (!done_o) begin
            #10;
            data_i = 8'b1111_1111;
            // $display("%b    %b", done_o, data_i);
        end

        // data_i = 8'b1111_1111;
        // while (!done_o) begin
        //     #10;
        // end
        $display("Sent!"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire