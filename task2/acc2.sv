// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 2.
//             :
//  Developers :  Dovydas Liutkus - s231676@student.dtu.dk
//             :  YOUR NAME HERE - s??????@student.dtu.dk
//             :
//  Purpose    :  Simple image inversion accelerator.
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
  //  STATE: READ_NEW_LINE
  //--------------------------------------------------------------------------
  // Reads new line of pixels into the oldest buffer, updates indices
  //==========================================================================

    // FSM states
    typedef enum logic [2:0] {
        IDLE,                 // Waiting for start
        LOAD_INITIAL_LINES,   // Read data from memory
        PROCESS_AND_WRITEBACK,// Process and write back to memory
        READ_NEW_LINE,        // Read new line from memory update indices
        DONE                  // Finished all pixels
    } state_t;

    state_t state, next_state;

    // Buffer file for three lines of image LINE_LENGTH+2 for mirrored border pixels
    logic [7:0]   buf_file [0:2][0:LINE_LENGTH+1];
    // signals starting with write_ are used in writeback, others are used for reading
    logic [15:0]  word_addr, next_word_addr, write_word_addr, next_write_word_addr;

    logic [1:0]   line_top, next_line_top, line_mid, line_bot; // Cycles through 0->1->2->0

    // Multiplex address based on read/write
    assign addr = we ? write_word_addr : word_addr;

    // Will be overwriting oldest line (line_bot)
    assign line_mid = (line_top + 1) % 3;
    assign line_bot = (line_top + 2) % 3;

    // Buffer pixel index
    logic [$clog2(LINE_LENGTH+2)-1:0] buf_pixel_idx, next_buf_pixel_idx, write_buf_pixel_idx, next_write_buf_pixel_idx;
    logic [$clog2(LINE_COUNT+2)-1:0 ] buf_line, next_buf_line, write_buf_line, next_write_buf_line;

    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state               <= IDLE;
            word_addr           <= 16'd0;
            buf_line            <= 3'd1;  // Start at line1 as line0 is mirrored from line1
            buf_pixel_idx       <= 1;     // Start at index=1 as index=0 is a copy of index=1
            // Write pointers start from 0
            write_buf_line      <= 0;
            write_buf_pixel_idx <= 1;
            write_word_addr     <= WRITEBACK_ADDR;  // Starting address for processed image (word address)
            line_top            <= 0;               // Initial top line
        end else begin
            state               <= next_state;
            buf_line            <= next_buf_line;
            buf_pixel_idx       <= next_buf_pixel_idx;
            word_addr           <= next_word_addr;
            write_buf_line      <=next_write_buf_line;
            write_buf_pixel_idx <=next_write_buf_pixel_idx;
            write_word_addr     <=next_write_word_addr; 
            line_top            <= next_line_top;

            case (state)
                LOAD_INITIAL_LINES,
                READ_NEW_LINE: begin
                  // Latch word into corresponding pixel in buffer
                  buf_file[buf_line][buf_pixel_idx + 0] <= dataR[7:0];
                  buf_file[buf_line][buf_pixel_idx + 1] <= dataR[15:8];
                  buf_file[buf_line][buf_pixel_idx + 2] <= dataR[23:16];
                  buf_file[buf_line][buf_pixel_idx + 3] <= dataR[31:24];

                  // If first line also record into the 0th (boundary condition)
                  if(buf_line == 1) begin
                    buf_file[buf_line-1][buf_pixel_idx + 0] <= dataR[7:0];
                    buf_file[buf_line-1][buf_pixel_idx + 1] <= dataR[15:8];
                    buf_file[buf_line-1][buf_pixel_idx + 2] <= dataR[23:16];
                    buf_file[buf_line-1][buf_pixel_idx + 3] <= dataR[31:24];
                  end

                  // If first word in line copy least-siginificant byte into 0th index (boundary condition)
                  if(buf_pixel_idx == 1)begin
                    buf_file[buf_line][buf_pixel_idx-1] <= dataR[7:0];
                    // If first line also repeat for line0
                    if(buf_line == 1)
                      buf_file[buf_line-1][buf_pixel_idx-1] <= dataR[7:0];
                  end
                  // If last word in line copy most-siginificant byte into last index (boundary condition)
                  if(buf_pixel_idx == LINE_LENGTH-3)begin
                    buf_file[buf_line][buf_pixel_idx+4] <= dataR[31:24];
                    // If first line also repeat for line0
                    if(buf_line == 1)
                      buf_file[buf_line-1][buf_pixel_idx+4] <= dataR[31:24];
                  end
                end
                default: ;
            endcase
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
        next_word_addr            = word_addr;
        next_buf_line             = buf_line;
        next_buf_pixel_idx        = buf_pixel_idx;
        next_line_top             = line_top;
        next_write_buf_line       = write_buf_line;
        next_write_buf_pixel_idx  = write_buf_pixel_idx;
        next_write_word_addr      = write_word_addr;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INITIAL_LINES;
                    en         = 1'b1;           // enable memory read
                    next_word_addr = word_addr + 1;
                end
            end
            LOAD_INITIAL_LINES: begin
                en = 1'b1;  // Keep memory enabled

                // If last word in line_buf increment line and if we were already writing into 2nd line go to next state
                if(buf_pixel_idx >= LINE_LENGTH-3) begin // -3 because last idx will be 349
                  if(buf_line == 2) begin
                    next_state = PROCESS_AND_WRITEBACK;
                  end 
                  next_buf_pixel_idx = 1; // Reset pixel index for new line
                  next_buf_line = buf_line + 1; // Increment buf_line after reading line, it will be used in READ_NEW_LINE
                end else begin
                  next_buf_pixel_idx  = buf_pixel_idx + 4;  // Increment by 4 because 4 bytes in word
                end
                next_word_addr = word_addr + 1; // Increment memory word address      
            end
            PROCESS_AND_WRITEBACK: begin
              //------------------------------------------------
              //              INSERT PROCESSING HERE
              //------------------------------------------------
              // For now only write back the same values
              en = 1'b1;
              we = 1'b1;

              // Pack 4 bytes into one word
              dataW = {
                  buf_file[write_buf_line][write_buf_pixel_idx + 3],
                  buf_file[write_buf_line][write_buf_pixel_idx + 2],
                  buf_file[write_buf_line][write_buf_pixel_idx + 1],
                  buf_file[write_buf_line][write_buf_pixel_idx + 0]
              };
              next_write_word_addr = write_word_addr + 1;
              // If line is done check whether last line, if not go to READ_NEW_LINE, if neither increment pointers and write again
              if (write_buf_pixel_idx >= LINE_LENGTH - 4) begin // -4 because last idx will be 348
                  if (write_buf_line == LINE_COUNT - 1) begin
                      next_state = DONE;
                  end else begin
                      next_write_buf_line = write_buf_line + 1;
                      next_write_buf_pixel_idx = 1; // TODO Won't need this when have processing
                      next_buf_line  = line_top;  // Prepare buf_line for READ_NEW_LINE
                      next_state = READ_NEW_LINE;
                  end
              end else begin
                  next_write_buf_pixel_idx = write_buf_pixel_idx + 4;
                  next_state = PROCESS_AND_WRITEBACK;
              end

            end
            READ_NEW_LINE: begin
              en = 1'b1;  // Enable memory
              // If full line has been read go back to process and writeback state
              if(buf_pixel_idx == LINE_LENGTH-3) begin
                next_state = PROCESS_AND_WRITEBACK;
                next_buf_line = 1; 
                next_buf_pixel_idx = 1; 
                // Update what is top line in buffer file
                next_line_top = (line_top + 1) % 3;
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
endmodule



