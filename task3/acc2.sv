// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 3.
//             :
//  Developers :  Dovydas Liutkus - s231676@student.dtu.dk
//             :  Tristan Baldit - s251525@student.dtu.dk
//             :
//  Purpose    :  Pipelined edge detector accelerator.
//             :  Reads 32-bit pixels from memory, inverts them,
//             :  and writes the inverted image after the original.
//             :
//
// ----------------------------------------------------------------------------//

module acc #(
    parameter int LINE_LENGTH     = 352,    // pixels per line (must be multiple of 4 for 32-bit words)
    parameter int LINE_COUNT      = 288,    
    parameter int WRITEBACK_ADDR  = 25344   // Starting address for storing processed image (word addressing) 
) (
    input  logic        clk,        // The clock.
    input  logic        reset,      // The reset signal. Active high.
    output logic [15:0] addr,       // Address bus for data (halfword_t).
    input  logic [31:0] dataR,      // Data read from memory (word_t).
    output logic [31:0] dataW,      // Data to write to memory (word_t).
    output logic        en,         // Memory enable (request signal).
    output logic        we,         // Write enable (1 = write, 0 = read).
    input  logic        start,      // Start processing.
    output logic        finish      // Done signal.
);

  // FSM states
  //==========================================================================
  //  STATE: LOAD_INITIAL_LINES (DONE)
  //--------------------------------------------------------------------------
  // Itteratively reads the first two lines (4 pixels at a time), adds boundry 
  // values for first and last pixel in line and copies line1 into line0 for boundry
  //==========================================================================
  //  STATE: PROCESS_AND_WRITEBACK
  //--------------------------------------------------------------------------
  // Itteratively calculates new pixel values and writes them to memory
  // (4 pixels at a time)
  //==========================================================================
  //  STATE: DELAY
  //--------------------------------------------------------------------------
  // One extra cycle for memory to finish write and fetch data for next read
  //==========================================================================
  //  STATE: READ_NEW_LINE
  //--------------------------------------------------------------------------
  // Reads new line of pixels into the oldest buffer, updates indices
  //==========================================================================

    typedef enum logic [2:0] {
        IDLE,                 // Waiting for start
        LOAD_INITIAL_LINES,   // Read data from memory
        PROCESS_AND_WRITEBACK,// Process and write back to memory
        LAST_WRITE,
        DELAY,
        READ_NEW_LINE,        // Read new line from memory update indices
        DONE                  // Finished all pixels
    } state_t;

    state_t state, next_state;
    
    // Buffer file for three lines of image LINE_LENGTH+2=354 lines for mirrored border pixels
    logic [7:0]   buf_file [0:2][0:LINE_LENGTH+1];
    
    // Buffer line index
    logic [2:0] buf_line_sel, next_buf_line_sel;

    // Buffer pixel index
    logic [$clog2(LINE_LENGTH+2)-1:0] buf_pixel_idx, next_buf_pixel_idx;

    // Address signals, seperate for read and write
    logic [15:0]  word_addr, next_word_addr, write_word_addr, next_write_word_addr;

    // Image line index for tracking how may lines have been written
    logic [$clog2(LINE_COUNT+2)-1:0 ] img_line_count, next_img_line_count ;

    logic first_line, next_first_line, last_line, next_last_line, save_to_buf, next_save_to_buf;

    // Below signals for keeping track which line is in which buf_file index. The values will iterate as follows
    // line_top | line_mid | line_bot
    //     0    |     1    |     2
    //     1    |     2    |     0
    //     2    |     0    |     1
    // This mechanism is so we always write to the line we're don't need anymore without moving anything inside the buffer
    logic [1:0]   line_top, next_line_top, line_mid, line_bot; 
    
    // Will be overwriting oldest line (line_bot)
    assign line_mid = (line_top + 1) % 3;
    assign line_bot = (line_top + 2) % 3;

    //------------------------------------------------------------
    // Working buffer (3 rows × 6 columns)
    // Holds a small 3x6 window extracted from buf_file
    //------------------------------------------------------------
    logic [7:0]   work_buffer [0:17];
    logic [31:0]  output_word;
    logic [$clog2(LINE_LENGTH+2)-1:0] work_pixel_idx, next_work_pixel_idx;

    // Try using same pixel index pointer for processing
    // assign work_pixel_idx = buf_pixel_idx;

   

    // Multiplex address based on read/write
    assign addr = we ? write_word_addr : word_addr;

    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state           <= IDLE;
            word_addr       <= 16'd0;
            buf_line_sel    <= 3'd1;            // Start at line1 as line0 is mirrored from line1 (boundry condition)
            buf_pixel_idx   <= 1;               // Start at index=1 as index=0 is copied from index=1 (boundry condition)
            img_line_count  <= 1; 
            write_word_addr <= WRITEBACK_ADDR;  // Starting address for processed image (word address)
            line_top        <= 0;               // Initial top line
            first_line      <= 1;               // For copying line1 into line0 (boundry condition)
            last_line       <= 0;
            work_pixel_idx  <= 1;
            save_to_buf     <= 0;
        end else begin
            state           <= next_state;
            buf_line_sel    <= next_buf_line_sel;
            buf_pixel_idx   <= next_buf_pixel_idx;
            word_addr       <= next_word_addr;
            img_line_count  <= next_img_line_count;
            write_word_addr <= next_write_word_addr; 
            line_top        <= next_line_top;
            first_line      <= next_first_line;
            last_line       <= next_last_line;
            work_pixel_idx  <= next_work_pixel_idx;
            save_to_buf     <= next_save_to_buf;

            if(save_to_buf) begin
                  // Latch word into corresponding pixel in buffer
                  buf_file[buf_line_sel][buf_pixel_idx + 0] <= dataR[7:0];
                  buf_file[buf_line_sel][buf_pixel_idx + 1] <= dataR[15:8];
                  buf_file[buf_line_sel][buf_pixel_idx + 2] <= dataR[23:16];
                  buf_file[buf_line_sel][buf_pixel_idx + 3] <= dataR[31:24];

                  // If first word in line copy least-siginificant byte (pixel) into 0th index (boundary condition)
                  if(buf_pixel_idx == 1)begin
                    buf_file[buf_line_sel][buf_pixel_idx-1] <= dataR[7:0];
                  end
                  // If last word in line copy most-siginificant byte into last index (boundary condition)
                  if(buf_pixel_idx == LINE_LENGTH-3)begin
                    buf_file[buf_line_sel][buf_pixel_idx+4] <= dataR[31:24];
                  end
            end
        end
    end

    // Combinational logic (FSM transitions and control)
    always_comb begin
        // Default assignments
        next_state = state;
        en         = 1'b0;
        we         = 1'b0;
        dataW      = 32'd0;
        finish     = 1'b0;
        next_word_addr        = word_addr;
        next_buf_line_sel     = buf_line_sel;
        next_buf_pixel_idx    = buf_pixel_idx;
        next_line_top         = line_top;
        next_img_line_count   = img_line_count;
        next_write_word_addr  = write_word_addr;
        next_first_line       = first_line;
        next_last_line        = last_line;
        next_work_pixel_idx   = work_pixel_idx;
        next_save_to_buf      = save_to_buf;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state      = LOAD_INITIAL_LINES;
                    en              = 1'b1;               // enable memory read
                    next_word_addr  = word_addr + 1;      // Preload next addr to start pipeline reading
                    next_save_to_buf = 1;
                end
            end
            LOAD_INITIAL_LINES: begin
                en = 1'b1;  // Keep memory enabled
                next_word_addr = word_addr + 1; // Increment memory word address 

                // If last word of the line increment line and if we were already writing into 2nd line go to next state
                if(buf_pixel_idx >= LINE_LENGTH-3) begin // pixel index starts at 1, so we do -3 because last idx will be 349
                  // next_first_line = 0;
                  if(buf_line_sel == 2) begin
                    next_state     = PROCESS_AND_WRITEBACK;
                    next_work_pixel_idx = 5;                // load next pixel group into computation pipeline
                    next_word_addr = word_addr;
                    next_save_to_buf = 0;
                  end 
                  next_buf_pixel_idx  = 1;                // Reset pixel index for new line
                  next_buf_line_sel   = buf_line_sel + 1; // Go to next line, the same pointer is also used in READ_NEW_LINE
                end else begin
                  next_buf_pixel_idx  = buf_pixel_idx + 4;  // Increment by 4 because 4 bytes in word
                end  
            end
            PROCESS_AND_WRITEBACK: begin

              // For now only write back the same values
              en = 1'b1;
              we = 1'b1;
              next_save_to_buf = 0;
              // Prepare processed word to write into memory
              dataW = {
                output_word[31:24],
                output_word[23:16],
                output_word[15:8],
                output_word[7:0]
              };
              next_write_word_addr = write_word_addr + 1;
              //       BELOW: LOGIC FOR SAME PIXEL WRITEBACK
              // If line is done check whether last line, if not go to READ_NEW_LINE, if neither increment pointers and write again
              if (work_pixel_idx >= LINE_LENGTH - 3) begin // -3 because last idx will be 348 (@rst work_pixel_idx=1)
                next_state = LAST_WRITE;
                next_work_pixel_idx = 1;             // RESET WORK PIPELINE ALREADY (IN CASE OF LAST LINE)
              end else begin
                  next_work_pixel_idx = next_work_pixel_idx + 4;
                  next_state = PROCESS_AND_WRITEBACK;
              end
            end
            LAST_WRITE:begin
              en = 1'b1;
              we = 1'b1;
              dataW = {
                output_word[31:24],
                output_word[23:16],
                output_word[15:8],
                output_word[7:0]
              };
              
              next_write_word_addr = write_word_addr + 1;
              
                if(img_line_count == LINE_COUNT) begin
                    next_state = DONE;
                  end else if (img_line_count == LINE_COUNT-1) begin
                      // For last line repeat PROCESS_AND_WRITEBACK no READ_NEW_LINE (boundry condition)
                      next_last_line = 1;
                      next_line_top = (line_top + 1) % 3; // Update what is top line in buffer file
                      next_state = PROCESS_AND_WRITEBACK;
                      next_work_pixel_idx = 5;             //start pipeline 
                  end else begin                     
                      next_buf_line_sel  = line_top;  // Prepare buf_line_sel for READ_NEW_LINE
                      next_state = DELAY;
                      next_work_pixel_idx = 1;
                  end
                  next_img_line_count = img_line_count + 1;
            end
            DELAY:begin
              // Needed to finish write and let addr pointer jump to read location
              en = 1'b1;
              next_first_line = 0; 
              next_word_addr = word_addr + 1;       
              next_state = READ_NEW_LINE;
              next_save_to_buf = 1;
            end
            READ_NEW_LINE: begin
              en = 1'b1;  // Enable memory
              // If full line has been read go back to process and writeback state
              if(buf_pixel_idx == LINE_LENGTH-3) begin
                next_state = PROCESS_AND_WRITEBACK;
                next_buf_line_sel   = 1; 
                next_buf_pixel_idx  = 1; 
                next_work_pixel_idx = 5;            // Start pipeline
                next_line_top = (line_top + 1) % 3; // Update what is top line in buffer file

                // // If last line re-read same line text time (boundry condition)
                // if(img_line_count == LINE_COUNT - 1)begin
                //   next_word_addr = 16'd25256;   // TODO Make expresion instead of magic number
                // end 
              end else begin
                next_state          = READ_NEW_LINE;
                next_buf_pixel_idx  = buf_pixel_idx + 4;  // Increment by 4 because 4 bytes in word
                next_word_addr      = word_addr + 1;      // Increment word address
              end
            end
            DONE: begin
                finish = 1'b1;
                if (!start)
                    next_state = IDLE; // allow restart
            end

            default: next_state = IDLE;
        endcase
    end

    //------------------------------------------------------------
    // BUILD THE WORK BUFFER (3 rows × 6 pixels)
    // Extracts a 3x6 region centered around work_pixel_idx
    //------------------------------------------------------------
    
    //For the pipeline to work we need to adapt the top/mid/bot idx for the work buffer when not in process state (when line_idx not updated yet)
    
    logic [1:0]   top, mid, bot;                               
    assign top = (state != PROCESS_AND_WRITEBACK && state != LOAD_INITIAL_LINES) ? line_mid : line_top;
    assign mid = (state != PROCESS_AND_WRITEBACK && state != LOAD_INITIAL_LINES) ? line_bot : line_mid;
    assign bot = (state != PROCESS_AND_WRITEBACK && state != LOAD_INITIAL_LINES) ? line_top : line_bot;
    
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin
            assign work_buffer[i]       = first_line ? buf_file[1][work_pixel_idx - 1 + i] : buf_file[top][work_pixel_idx - 1 + i]; // If first line is being processed use line 1 for processing
            assign work_buffer[i + 6]   = buf_file[mid][work_pixel_idx - 1 + i];
            // If last line use middle line (boundary condition )
            assign work_buffer[i + 12]  = (last_line || next_last_line) ? buf_file[mid][work_pixel_idx - 1 + i] : buf_file[bot][work_pixel_idx - 1 + i];
        end
    endgenerate

    //------------------------------------------------------------
    // SOBEL FILTER CALCULATION (pixels 1 → 4 of the mid line)
    // Computes Dx, Dy and approximate magnitude |D| = |Dx| + |Dy|
    //------------------------------------------------------------
    logic [7:0] sobel_result [1:4];
    logic signed [10:0] Dx [1:4], Dy [1:4];
    logic signed [10:0] Dx_r [1:4], Dy_r [1:4];

   generate
    for (i = 1; i <= 4; i++) begin : sobel_pipe

        // ----------------------------
        // 3×3 pixel window
        // ----------------------------
        wire [7:0] s11 = work_buffer[i - 1];
        wire [7:0] s12 = work_buffer[i];
        wire [7:0] s13 = work_buffer[i + 1];
        wire [7:0] s21 = work_buffer[6 + i - 1];
        wire [7:0] s22 = work_buffer[6 + i];
        wire [7:0] s23 = work_buffer[6 + i + 1];
        wire [7:0] s31 = work_buffer[12 + i - 1];
        wire [7:0] s32 = work_buffer[12 + i];
        wire [7:0] s33 = work_buffer[12 + i + 1];

        // ----------------------------
        // Stage-1 COMB: Dx, Dy
        // ----------------------------
        assign Dx[i] =
              $signed({1'b0, s13}) - $signed({1'b0, s11})
            + (($signed({1'b0, s23}) - $signed({1'b0, s21})) <<< 1)
            + $signed({1'b0, s33}) - $signed({1'b0, s31});

        assign Dy[i] =
              $signed({1'b0, s11}) - $signed({1'b0, s31})
            + (($signed({1'b0, s12}) - $signed({1'b0, s32})) <<< 1)
            + $signed({1'b0, s13}) - $signed({1'b0, s33});


        // =======================================================
        // Stage-1 FF: register Dx_r, Dy_r
        // =======================================================
        always_ff @(posedge clk) begin
            Dx_r[i] <= Dx[i];
            Dy_r[i] <= Dy[i];
        end


        // =======================================================
        // Stage-2 COMB: abs, add, clamp
        // =======================================================
        wire [10:0] absDx = Dx_r[i][10] ? -Dx_r[i] : Dx_r[i];
        wire [10:0] absDy = Dy_r[i][10] ? -Dy_r[i] : Dy_r[i];
        wire [11:0] mag   = absDx + absDy;
        wire [7:0]  pix   = (mag > 12'd255) ? 8'd255 : mag[7:0];


        // =======================================================
        // Stage-2 FF: register final Sobel result
        // =======================================================
        assign sobel_result[i] = pix;
    end
  endgenerate

    //------------------------------------------------------------
    // PACK OUTPUT WORD (4 × 8-bit Sobel results)
    //------------------------------------------------------------
    assign output_word = {sobel_result[4], sobel_result[3], sobel_result[2], sobel_result[1]};
endmodule



