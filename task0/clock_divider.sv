//------------------------------------------------------------------------------
//
// Wrapper for the Xilinx clock divider.
//
// Author     : Otto Westy Rasmussen <s203838@dtu.dk>
//
//----------------------------------------------------------------------------

module clock_divider #(
    parameter DIVIDE = 2
) (
    input logic clk_in,
    output logic clk_out
);

  logic clk_fb;

// PLLE2_BASE: Base Phase Locked Loop (PLL)

PLLE2_BASE #(
   .CLKFBOUT_MULT(8),        // Multiply value for all CLKOUT, (2-64)
   .CLKOUT0_DIVIDE(DIVIDE*8),
   .CLKIN1_PERIOD(10.0)
)
PLLE2_BASE_inst (
   .CLKOUT0(clk_out),   // 1-bit output: CLKOUT0
   .CLKOUT1(),   // 1-bit output: CLKOUT1
   .CLKOUT2(),   // 1-bit output: CLKOUT2
   .CLKOUT3(),   // 1-bit output: CLKOUT3
   .CLKOUT4(),   // 1-bit output: CLKOUT4
   .CLKOUT5(),   // 1-bit output: CLKOUT5

   // Feedback Clocks: 1-bit (each) output: Clock feedback ports
   .CLKFBOUT(clk_fb), // 1-bit output: Feedback clock
   .LOCKED(),     // 1-bit output: LOCK
   .CLKIN1(clk_in),     // 1-bit input: Input clock

   // Control Ports: 1-bit (each) input: PLL control ports
   .PWRDWN(0),     // 1-bit input: Power-down
   .RST(0),           // 1-bit input: Reset

   // Feedback Clocks: 1-bit (each) input: Clock feedback ports
   .CLKFBIN(clk_fb)    // 1-bit input: Feedback clock
);

endmodule
