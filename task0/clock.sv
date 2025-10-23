// -----------------------------------------------------------------------------
//
//  Title      :  Simple clock generator.
//             :
//  Developers :  Otto Westy Rasmussen <s203838@dtu.dk>
//             :
//  Purpose    :  This design contains a clock generator.
//             :
//  Revision   :  02203 fall 2025 v.1.0
//
// -----------------------------------------------------------------------------

//------------------------------------------------------------------------------
// A simple clock generator. The period is specified in a generic and defaults
// to 50 ns.
//------------------------------------------------------------------------------

module clock #(
    parameter time PERIOD = 50ns
) (
    output logic clk,
    input  logic stop
);
    initial begin
        clk = 0;
        forever while (!stop) begin
            #(PERIOD/2) clk = ~clk;
        end
    end
endmodule
