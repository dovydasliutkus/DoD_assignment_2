module datapath #(
    parameter int SIZE_ROW = 352
)(
    input  logic                            clk,            // The clock.
    input  logic                            reset,          // The reset signal. Active high.
    input  logic                            i_word,         // pixels read
    input  logic                            buffer_shift,
    input  logic [8:0]                      buffer_write,
    input  logic [$clog2(SIZE_ROW/4)-1:0]   write_index,
    output logic [31:0]                     o_word,         // news pixels to write
);

logic [7:0] line_a [0:SIZE_ROW-1];
logic [7:0] line_b [0:SIZE_ROW-1];
logic [7:0] line_c [0:SIZE_ROW-1];

logic [7:0] window [0:17]

three_line_buffer #(
    .SIZE_ROW(SIZE_ROW)
) u_line_buffer (
   .clk          (clk),
   .rst          (reset),
   .write_en     (buffer_write),
   .write_sel    (write_index),
   .word_in      (i_word),
   .shift_en     (buffer_shift),
   .pixels_out_a (line_a),
   .pixels_out_b (line_b),
   .pixels_out_c (line_c)
);

lines_mux #(
    .SIZE_ROW(SIZE_ROW)
) u_lines_mux (
   .line0 (line_a),
   .line1 (line_b),
   .line2 (line_c),
   .win   (window)
);

endmodule