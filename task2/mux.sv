module lines_mux #(
    parameter SIZE_ROW = 352
)(
    input  wire [7:0] line0 [0:SIZE_ROW-1],
    input  wire [7:0] line1 [0:SIZE_ROW-1],
    input  wire [7:0] line2 [0:SIZE_ROW-1],
    input  wire [$clog2(SIZE_ROW)-1:0] sel,
    output wire [7:0] win [0:17]
);
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin
            assign win[i]      = line0[sel - 1 + i];
            assign win[i + 6]  = line1[sel - 1 + i];
            assign win[i + 12] = line2[sel - 1 + i];
        end
    endgenerate
endmodule