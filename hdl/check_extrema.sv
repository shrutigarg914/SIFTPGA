`timescale 1ns / 1ps
`default_nettype none

// exploiting the fact that we only have two images per octave
// after we run DoG on the gaussian pyramid
// we shall check both images simultaneously for extrema
// a more principled way to do this would be to just do it one by one
// but ope

// NOTE: the data is SIGNED!!!!!!!!!!!!!!!!!!!

// INPUT: given two BRAMs, andis active when enable low
// ACTION: finds all extrema 
// HOW: for each x, y, check if that is extremum
// if is extremum then set is_extremum high for a cycle
// x, y will hold the value where extremum was found
// lastly hold done_checking high when done with the logic
// NOTE: will need to check how many cycles needed to check one pixel
// if too fast might need to put in a pause until parent module gives go ahead to find next extremum
module check_extrema #(
  parameter BIT_DEPTH = 9,// 8 bit greyscale --> signed differences gives us 9 bits
  parameter ABS_CONTRAST_THRESHOLD = 4, // in the ref cpp code the threshold is set for 0.015
  parameter DIMENSION = 4
  ) (
  input wire clk,
  input wire rst_in,
  // input wire have_prev,
  // input wire have_next,

  input wire signed [BIT_DEPTH-1:0] first_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address,
  
  input wire signed [BIT_DEPTH-1:0] second_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] second_address,
  
  input wire enable,
  // input wire [BIT_DEPTH-1:0] next_data,
  // input wire [$clog2(DIMENSION*DIMENSION)-1:0] next_address,
  // input wire [BIT_DEPTH-1:0] prev_data,
  // input wire [$clog2(DIMENSION*DIMENSION)-1:0] prev_address,
  output logic [$clog2(DIMENSION)-1:0] x,
  output logic [$clog2(DIMENSION)-1:0] y,
  output logic first_is_extremum,
  output logic second_is_extremum,
  output logic done_checking,
  output logic [2:0] state_number,
  output logic first_is_min,
  output logic first_is_max,
  output logic second_is_min,
  output logic second_is_max,  
  output logic [$clog2(DIMENSION)-1:0] read_x,
  output logic [$clog2(DIMENSION)-1:0] read_y,
  output logic read
  );
    
  typedef enum {TOP=0, TOPR=1, TOPL=2, BOT=3, BOTR=4, BOTL=5, RIGHT=6, LEFT=7, MIDDLE=8, NULL=9} sub_module_state;
  sub_module_state pixel_pos;


  // logic [$clog2(DIMENSION)-1:0] read_x;
  // logic [$clog2(DIMENSION)-1:0] read_y;

  // pixel for first BRAM
  logic signed [BIT_DEPTH-1:0] first_top;
  logic signed [BIT_DEPTH-1:0] first_top_right;
  logic signed [BIT_DEPTH-1:0] first_top_left;
  logic signed [BIT_DEPTH-1:0] first_bottom;
  logic signed [BIT_DEPTH-1:0] first_bottom_right;
  logic signed [BIT_DEPTH-1:0] first_bottom_left;
  logic signed [BIT_DEPTH-1:0] first_right;
  logic signed [BIT_DEPTH-1:0] first_left;
  logic signed [BIT_DEPTH-1:0] first_middle;
  
  // pixels for second BRAM
  logic signed [BIT_DEPTH-1:0] second_top;
  logic signed [BIT_DEPTH-1:0] second_top_right;
  logic signed [BIT_DEPTH-1:0] second_top_left;
  logic signed [BIT_DEPTH-1:0] second_bottom;
  logic signed [BIT_DEPTH-1:0] second_bottom_right;
  logic signed [BIT_DEPTH-1:0] second_bottom_left;
  logic signed [BIT_DEPTH-1:0] second_right;
  logic signed [BIT_DEPTH-1:0] second_left;
  logic signed [BIT_DEPTH-1:0] second_middle;

  // logic first_is_min, first_is_max;
  // logic second_is_min, second_is_max;

  // IDLE=0, START_ROW=1, CHECK=2, INCREMENT=3, SHIFT_RIGHT=4
  always_comb begin
    case(state)
      IDLE : state_number = 0;
      START_ROW : state_number = 1'b1;
      CHECK : state_number = 2'b10;
      INCREMENT : state_number = 2'b11;
      SHIFT_RIGHT : state_number = 3'b100;
    endcase
  end

  // this logic combinatorially sets read addresses depending on which neighbour we want to be setting 
  always_comb begin
    case(pixel_pos)
      TOP : begin
        read_x = x;
        read_y = y - 1'b1;
      end
      TOPR : begin
        read_x = x + 1'b1;
        read_y = y - 1'b1;
      end
      TOPL : begin
        read_x = x - 1'b1;
        read_y = y - 1'b1;
      end
      BOT : begin
        read_x = x;
        read_y = y + 1'b1;
      end
      BOTR : begin
        read_x = x + 1'b1;
        read_y = y + 1'b1;
      end
      BOTL : begin
        read_x = x - 1'b1;
        read_y = y + 1'b1;
      end
      RIGHT : begin
        read_x = x + 1'b1;
        read_y = y;
      end
      LEFT : begin
        read_x = x - 1'b1;
        read_y = y;
      end
      MIDDLE : begin
        read_x = x;
        read_y = y;
      end
    endcase
    // static combinaorial check to see if the first pixel is an extremum
    first_is_min = (first_middle < first_left) && (first_middle < first_right) &&
    (first_middle < first_top) && (first_middle < first_top_right) && (first_middle < first_top_left) &&
    (first_middle < first_bottom) && (first_middle < first_bottom_right) && (first_middle < first_bottom_left) && 
    (first_middle < second_middle) && (first_middle < second_left) && (first_middle < second_right) &&
    (first_middle < second_top) && (first_middle < second_top_right) && (first_middle < second_top_left) &&
    (first_middle < second_bottom) && (first_middle < second_bottom_right) && (first_middle < second_bottom_left);

    first_is_max = (first_middle > first_left) && (first_middle > first_right) &&
    (first_middle > first_top) && (first_middle > first_top_right) && (first_middle > first_top_left) &&
    (first_middle > first_bottom) && (first_middle > first_bottom_right) && (first_middle > first_bottom_left) &&
    (first_middle > second_middle) && (first_middle > second_left) && (first_middle > second_right) &&
    (first_middle > second_top) && (first_middle > second_top_right) && (first_middle > second_top_left) &&
    (first_middle > second_bottom) && (first_middle > second_bottom_right) && (first_middle > second_bottom_left);
    
    // static combinaorial check to see if the second pixel is an extremum
    second_is_min = (second_middle < second_left) && (second_middle < second_right) &&
    (second_middle < second_top) && (second_middle < second_top_right) && (second_middle < second_top_left) &&
    (second_middle < second_bottom) && (second_middle < second_bottom_right) && (second_middle < second_bottom_left) &&
    (second_middle < first_middle) && (second_middle < first_left) && (second_middle < first_right) &&
    (second_middle < first_top) && (second_middle < first_top_right) && (second_middle < first_top_left) &&
    (second_middle < first_bottom) && (second_middle < first_bottom_right) && (second_middle < first_bottom_left);

    second_is_max = (second_middle > second_left) && (second_middle > second_right) &&
    (second_middle > second_top) && (second_middle > second_top_right) && (second_middle > second_top_left) &&
    (second_middle > second_bottom) && (second_middle > second_bottom_right) && (second_middle > second_bottom_left) &&
    (second_middle > first_middle) && (second_middle > first_left) && (second_middle > first_right) &&
    (second_middle > first_top) && (second_middle > first_top_right) && (second_middle > first_top_left) &&
    (second_middle > first_bottom) && (second_middle > first_bottom_right) && (second_middle > first_bottom_left);   
  end

  // if we set read_x, read_y and then set read high, 
  // when reader puts out read_done, we can save the values from
  // first and second read values as the values at that location 
  // logic signed [BIT_DEPTH-1:0] first_read_value;
  // logic signed [BIT_DEPTH-1:0] second_read_value;
  logic reader_busy, reader_done;
  
  read_pixel #(.DIMENSION(DIMENSION)) reader (
  .clk(clk),
  .rst_in(rst_in),
  .first_data(first_data),
  .first_address(first_address),
  .second_data(second_data),
  .second_address(second_address),
  .input_ready(read),
  .x(read_x),
  .y(read_y),
  // .first_pixel_value(first_read_value),
  // .second_pixel_value(second_read_value),
  .busy(reader_busy),
  .done(reader_done)
  );

  typedef enum {IDLE=0, START_ROW=1, CHECK=2, INCREMENT=3, SHIFT_RIGHT=4} module_state;
  module_state state;

  always_ff @(posedge clk) begin
    if (rst_in) begin
      state <= IDLE;
      pixel_pos <= NULL;
      read <= 1'b0;
      first_is_extremum <= 1'b0;
      second_is_extremum <= 1'b0;
      x <= 1'b1;
      y <= 1'b1;
      done_checking <= 1'b0;
    end else begin
      case(state)
        IDLE : if (enable) begin
          x <= 1'b1;
          y <= 1'b1;
          state <= START_ROW;
          pixel_pos <= NULL;
          // read <= 1'b1;
          done_checking <= 1'b0;
        end else begin
          state <= IDLE;
          read <= 1'b0;
          done_checking <= 1'b0;
        end
        START_ROW : case(pixel_pos)
          TOP : if (reader_done) begin
            first_top <= first_data;
            second_top <= second_data;
            pixel_pos <= TOPR;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          TOPR : if (reader_done) begin
            first_top_right <= first_data;
            second_top_right <= second_data;
            pixel_pos <= RIGHT;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          RIGHT : if (reader_done) begin
            first_right <= first_data;
            second_right <= second_data;
            pixel_pos <= BOTR;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          BOTR : if (reader_done) begin
            first_bottom_right <= first_data;
            second_bottom_right <= second_data;
            pixel_pos <= BOT;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          BOT : if (reader_done) begin
            first_bottom <= first_data;
            second_bottom <= second_data;
            pixel_pos <= BOTL;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          BOTL : if (reader_done) begin
            first_bottom_left <= first_data;
            second_bottom_left <= second_data;
            pixel_pos <= LEFT;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          LEFT : if (reader_done) begin
            first_left <= first_data;
            second_left <= second_data;
            pixel_pos <= TOPL;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          TOPL : if (reader_done) begin
            first_top_left <= first_data;
            second_top_left <= second_data;
            pixel_pos <= MIDDLE;
            read <= 1'b1;
          end else begin
            read <= 1'b0;
          end
          MIDDLE : if (reader_done) begin
            first_middle <= first_data;
            second_middle <= second_data;
            pixel_pos <= NULL;
            state <= CHECK;
          end else begin
            read <= 1'b0;
          end
          NULL : begin
            pixel_pos <= TOP;
            read <= 1'b1;
          end
        endcase
        CHECK : begin 
          if (first_is_min || first_is_max) begin
            first_is_extremum <= 1'b1;
          end
          if (second_is_min || second_is_max) begin
            second_is_extremum <= 1'b1;
          end
          state <= INCREMENT;
        end
        INCREMENT : begin
          first_is_extremum <= 1'b0;
          second_is_extremum <= 1'b0;
          if (x < DIMENSION - 2) begin
            x <= x + 1'b1;
            state <= SHIFT_RIGHT;
            pixel_pos <= NULL;
          end else if (y < DIMENSION - 2) begin
            x <= 1'b1;
            y <= y+1'b1;
            state <= START_ROW;
            pixel_pos <= NULL;
          end else begin
            state <= IDLE;
            done_checking <= 1'b1;
          end
        end
        SHIFT_RIGHT : begin
          case(pixel_pos)
            NULL : begin
              // move values over for the first BRAM
              first_top_left <= first_top;
              first_bottom_left <= first_bottom;
              first_left <= first_middle;
              first_top <= first_top_right;
              first_bottom <= first_bottom_right;
              first_middle <= first_right;

              // move values over for the second BRAM
              second_top_left <= second_top;
              second_bottom_left <= second_bottom;
              second_left <= second_middle;
              second_top <= second_top_right;
              second_bottom <= second_bottom_right;
              second_middle <= second_right;
              
              // start loading the three remaining pixels
              pixel_pos <= TOPR;
              read <= 1'b1;
            end
            TOPR : if (reader_done) begin
              first_top_right <= first_data;
              second_top_right <= second_data;
              pixel_pos <= RIGHT;
              read <= 1'b1;
            end else begin
              read <= 1'b0;
            end
            RIGHT : if (reader_done) begin
              first_right <= first_data;
              second_right <= second_data;
              pixel_pos <= BOTR;
              read <= 1'b1;
            end else begin
              read <= 1'b0;
            end
            BOTR : if (reader_done) begin
              first_bottom_right <= first_data;
              second_bottom_right <= second_data;
              pixel_pos <= NULL;
              state <= CHECK;
            end else begin
              read <= 1'b0;
            end
            default : pixel_pos <= NULL;
          endcase
        end
      endcase
    end
  end

endmodule // extrema

// a sub module to check for extrema, and owns the address setters for both BRAMs
module read_pixel #(
  parameter BIT_DEPTH = 9,
  parameter DIMENSION = 4
  ) (
  input wire clk,
  input wire rst_in,

  input wire signed [BIT_DEPTH-1:0] first_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] first_address,
  
  input wire signed [BIT_DEPTH-1:0] second_data,
  output logic [$clog2(DIMENSION*DIMENSION)-1:0] second_address,

  input wire input_ready,
  input wire [$clog2(DIMENSION)-1:0] x,
  input wire [$clog2(DIMENSION)-1:0] y,
  output logic busy,
  output logic done// goes high for one cycle when read is done
  );
    typedef enum {IDLE=0, BUSY=1} reader_state;
    reader_state state;

    logic [1:0] counter;
    logic [$clog2(DIMENSION*DIMENSION)-1:0] address;
    assign address = y * DIMENSION + x;
    always_ff @(posedge clk) begin
      if (rst_in) begin
        counter <= 0;
      end else begin
        case(state)
          IDLE: if (input_ready) begin
            state <= BUSY;
            first_address <= address;
            second_address <= address;
            counter <= 0; 
            busy <= 1'b1;
            done <= 1'b0;
          end else begin
            state <= IDLE;
            done <= 1'b0;
          end
          BUSY: if (counter==2'b10) begin
            state <= IDLE;
            done <= 1'b1;
            busy <= 1'b0;
          end else begin
            counter <= counter + 1'b1;
          end
        endcase
      end
    end       
endmodule //read_pixel


`default_nettype wire
