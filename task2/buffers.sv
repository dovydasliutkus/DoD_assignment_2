module three_lines_buffer #(
    parameter int SIZE_ROW = 352
)(
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            write_en,
    input  logic [$clog2(SIZE_ROW/4)-1:0]   write_sel,
    input  logic [31:0]                     word_in,
    input  logic                            shift_en,
    output logic [7:0]                      pixels_out_a [0:SIZE_ROW-1],
    output logic [7:0]                      pixels_out_b [0:SIZE_ROW-1],
    output logic [7:0]                      pixels_out_c [0:SIZE_ROW-1]
);

    // Line buffers
    logic [7:0] line_a [0:SIZE_ROW-1];
    logic [7:0] line_b [0:SIZE_ROW-1];
    logic [7:0] line_c [0:SIZE_ROW-1];

    integer i;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < SIZE_ROW; i++) begin
                line_a[i] <= '0;
                line_b[i] <= '0;
                line_c[i] <= '0;
            end
        end else begin
            // Write one pixel into line A
            if (write_en)
                line_a[4*write_sel] <= pixel_in[31:24];
                line_a[4*write_sel+1] <= pixel_in[23:16];
                line_a[4*write_sel+2] <= pixel_in[15:8];
                line_a[4*write_sel+3] <= pixel_in[7:0];
            // Shift lines when shift_en asserted
            if (shift_en) begin
                for (i = 0; i < SIZE_ROW; i++) begin
                    line_c[i] <= line_b[i];
                    line_b[i] <= line_a[i];
                end
            end
        end
    end

    // Output connections
    // These outputs are direct copies of the internal buffers
    always_comb begin
        for (int j = 0; j < SIZE_ROW; j++) begin
            pixels_out_a[j] = line_a[j];
            pixels_out_b[j] = line_b[j];
            pixels_out_c[j] = line_c[j];
        end
    end
endmodule

