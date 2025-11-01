//============================================================
// Module: datapath
// Description:
//   This module implements a 3-line sliding window buffer for
//   image processing and applies a Sobel edge detection filter
//   to generate 4 output pixels per clock cycle.
//============================================================

module datapath #(
    parameter int LINE_LENGTH = 352
)(
    input  logic                                clk,            // Clock signal
    input  logic                                reset,          // Active-high reset
    input  logic [31:0]                         i_word,         // 4 input pixels (each 8 bits)
    input  logic [2:0]                          buf_line_sel,   // Line to write new pixels
    input  logic [$clog2(LINE_LENGTH+2)-1:0]    buf_pixel_idx,  // Write pixel index
    input  logic                                buffer_write,   // Write enable
    input  logic [1:0]                          top_line,       // Index of the current top line in buffer
    input  logic [$clog2(LINE_LENGTH+2)-1:0]    work_pixel_idx, // Index for the working pixel position
    output logic [31:0]                         output_word     // 4 output pixels after Sobel filtering
);

    //------------------------------------------------------------
    // 3-line image buffer
    // Each line stores (LINE_LENGTH + 2) pixels (padding for borders)
    //------------------------------------------------------------
    logic [7:0] buf_file [0:2][0:LINE_LENGTH+1];

    //------------------------------------------------------------
    // Working buffer (3 rows × 6 columns)
    // Holds a small 3x6 window extracted from buf_file
    //------------------------------------------------------------
    logic [7:0] work_buffer [0:17];

    //------------------------------------------------------------
    // BUFFER WRITE PROCESS
    // Writes 4 pixels (one 32-bit word) to the selected buffer line
    //------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            integer x, y;
            for (y = 0; y < 3; y = y + 1)
                for (x = 0; x < LINE_LENGTH + 2; x = x + 1)
                    buf_file[y][x] <= 8'd0;
        end 
        else if (buffer_write) begin
            buf_file[buf_line_sel][buf_pixel_idx + 0] <= i_word[7:0];
            buf_file[buf_line_sel][buf_pixel_idx + 1] <= i_word[15:8];
            buf_file[buf_line_sel][buf_pixel_idx + 2] <= i_word[23:16];
            buf_file[buf_line_sel][buf_pixel_idx + 3] <= i_word[31:24];
        end
    end

    //------------------------------------------------------------
    // BUILD THE WORK BUFFER (3 rows × 6 pixels)
    // Extracts a 3x6 region centered around work_pixel_idx
    //------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin
            assign work_buffer[i]       = buf_file[top_line][work_pixel_idx - 1 + i];
            assign work_buffer[i + 6]   = buf_file[(top_line + 1) % 3][work_pixel_idx - 1 + i];
            assign work_buffer[i + 12]  = buf_file[(top_line + 2) % 3][work_pixel_idx - 1 + i];
        end
    endgenerate

    //------------------------------------------------------------
    // SOBEL FILTER CALCULATION (pixels 1 → 4 of the mid line)
    // Computes Dx, Dy and approximate magnitude |D| = |Dx| + |Dy|
    //------------------------------------------------------------
    logic [7:0] sobel_result [1:4];

    generate
        for (i = 1; i <= 4; i = i + 1) begin : sobel_calc
            // 3x3 pixel window
            wire [7:0] s11 = work_buffer[i - 1];
            wire [7:0] s12 = work_buffer[i];
            wire [7:0] s13 = work_buffer[i + 1];
            wire [7:0] s21 = work_buffer[6 + i - 1];
            wire [7:0] s22 = work_buffer[6 + i];
            wire [7:0] s23 = work_buffer[6 + i + 1];
            wire [7:0] s31 = work_buffer[12 + i - 1];
            wire [7:0] s32 = work_buffer[12 + i];
            wire [7:0] s33 = work_buffer[12 + i + 1];

            // Sobel horizontal gradient (Dx)
            wire signed [10:0] Dx =
                  $signed({1'b0, s13}) - $signed({1'b0, s11})
                + (($signed({1'b0, s23}) - $signed({1'b0, s21})) <<< 1)
                + $signed({1'b0, s33}) - $signed({1'b0, s31});

            // Sobel vertical gradient (Dy)
            wire signed [10:0] Dy =
                  $signed({1'b0, s11}) - $signed({1'b0, s31})
                + (($signed({1'b0, s12}) - $signed({1'b0, s32})) <<< 1)
                + $signed({1'b0, s13}) - $signed({1'b0, s33});

            // Absolute values
            wire [10:0] absDx = Dx[10] ? -Dx : Dx;
            wire [10:0] absDy = Dy[10] ? -Dy : Dy;

            // Approximate gradient magnitude
            wire [11:0] D = absDx + absDy;

            // Clamp to 8 bits
            assign sobel_result[i] = (D > 12'd255) ? 8'd255 : D[7:0];
        end
    endgenerate

    //------------------------------------------------------------
    // PACK OUTPUT WORD (4 × 8-bit Sobel results)
    //------------------------------------------------------------
    assign output_word = {sobel_result[4], sobel_result[3], sobel_result[2], sobel_result[1]};

endmodule