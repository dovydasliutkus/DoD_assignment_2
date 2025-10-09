// -----------------------------------------------------------------------------
// SystemVerilog Testbench for task 2 of the Edge-Detection design project
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module testbench;
    // Clock and reset signals
    logic clk;
    logic reset;
    logic StopSimulation = 0;
    localparam string load_file_name = "/home/ottow/Documents/02203_A2_code/task2/pic1.pgm"; // Path to the input PGM file

    // Accelerator and memory signals
    logic [15:0] addr;
    logic [31:0] dataR;
    logic [31:0] dataW;
    logic en;
    logic we;
    logic start;
    logic finish;

    // Instantiate clock generator
    clock #(.PERIOD(80)) SysClk (
        .clk(clk),
        .stop(StopSimulation)
    );

    // Instantiate accelerator
    acc Accelerator (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .dataR(dataR),
        .dataW(dataW),
        .en(en),
        .we(we),
        .start(start),
        .finish(finish)
    );

    // Instantiate memory
    memory2 #(.load_file_name(load_file_name)) Memory (
        .clk(clk),
        .en(en),
        .we(we),
        .addr(addr),
        .dataW(dataW),
        .dataR(dataR),
        .dump_image(finish)
    );

    // Reset and start logic
    initial begin
        reset = 1;
        start = 0;
        #180 reset = 0;

        // Wait for reset deassertion and clock edge
        @(posedge clk);
        start = 1;

        // Wait for accelerator to finish
        wait (finish);
        start = 0;

        @(posedge clk);
        $display("Test finished successfully! Simulation Stopped!");
        StopSimulation = 1;
        $finish;
    end
endmodule
