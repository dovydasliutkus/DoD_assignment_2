// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 0.
//             :
//  Developers :  YOUR NAME HERE - s??????@student.dtu.dk
//             :  YOUR NAME HERE - s??????@student.dtu.dk
//             :
//  Purpose    :  Simple image inversion accelerator.
//             :  Reads 32-bit pixels from memory, inverts them,
//             :  and writes the inverted image after the original.
//             :
//
// ----------------------------------------------------------------------------//

module acc (
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
    typedef enum logic [2:0] {
        S_IDLE,       // Waiting for start
        S_READ,       // Read data from memory
        S_WRITE,      // Write inverted data back
        S_DONE        // Finished all pixels
    } state_t;

    state_t state, next_state;

    // Internal registers
    logic [15:0] addr_reg;                  // 16-bit address counter (for up to >65k)
    parameter int IMG_MEM_SIZE = 25344;    // Number of 32-bit words in the image
    
    // Temporary for write address
    logic [15:0] write_addr;
    assign write_addr = addr_reg + IMG_MEM_SIZE;

    // Sequential logic (state + address + pixel register)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= S_IDLE;
            addr_reg  <= 16'd0;
        end else begin
            state <= next_state;

            case (state)
                S_WRITE: begin
                    // Increment address after write
                    addr_reg <= addr_reg + 1;
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
        addr       = 16'd0;  // default

        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_READ;
                end
            end

            S_READ: begin
                en         = 1'b1;           // enable memory read
                we         = 1'b0;           // read mode
                addr       = addr_reg[15:0]; // read from original image
                next_state = S_WRITE;
            end

            S_WRITE: begin
                en         = 1'b1;   // enable memory write
                we         = 1'b1;   // write mode
                dataW      = ~dataR; // Inversion of the data from the RAM
                addr       =  write_addr; // write after original image

                if (addr_reg == IMG_MEM_SIZE - 1)
                    next_state = S_DONE;
                else
                    next_state = S_READ;
            end

            S_DONE: begin
                finish = 1'b1;
                if (!start)
                    next_state = S_IDLE; // allow restart
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule



