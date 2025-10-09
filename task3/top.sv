// -----------------------------------------------------------------------------
//
//  Title      :  Top level for task 2 of the Edge-Detection design project.
//             :
//  Developers :  Otto Westy Rasmussen - s203838@dtu.dk
//             :
//  Purpose    :  A top-level entity connecting all the components.
//             :
//  Revision   :  02203 fall 2025 v.1.0
//
// -----------------------------------------------------------------------------

module top (
    input  logic clk_100mhz,
    input  logic rst,
    output logic led,
    input  logic start,
    input  logic serial_tx,   // from the PC
    output logic serial_rx    // to the PC
);
    // Parameters
    localparam int CLK_DIVISION_FACTOR = 2;

    // Internal signals
    logic clk;
    logic [15:0] addr;
    logic [31:0] dataR, dataW;
    logic en, we, finish, start_db;

    logic mem_enb, mem_web;
    logic [15:0] mem_addrb;
    logic [31:0] mem_dib, mem_dob;

    logic [7:0] data_stream_in, data_stream_out;
    logic data_stream_in_stb, data_stream_in_ack, data_stream_out_stb;

    logic tx, rx;

    assign tx = serial_tx;
    assign serial_rx = rx;
    // LED output
    assign led = finish;

    // Clock divider instance
    clock_divider #(.DIVIDE(CLK_DIVISION_FACTOR)) clock_divider_inst_0 (
        .clk_in(clk_100mhz),
        .clk_out(clk)
    );

    // Debounce instance
    debounce debounce_inst_0 (
        .clk(clk),
        .reset(rst),
        .sw(start),
        .db_level(start_db),
        .db_tick()
    );

    // Accelerator instance
    acc accelerator_inst_0 (
        .clk(clk),
        .reset(rst),
        .addr(addr),
        .dataR(dataR),
        .dataW(dataW),
        .en(en),
        .we(we),
        .start(start_db),
        .finish(finish)
    );

    // Controller instance
    controller controller_inst_0 (
        .clk(clk),
        .reset(rst),
        .data_stream_tx(data_stream_in),
        .data_stream_tx_stb(data_stream_in_stb),
        .data_stream_tx_ack(data_stream_in_ack),
        .data_stream_rx(data_stream_out),
        .data_stream_rx_stb(data_stream_out_stb),
        .mem_en(mem_enb),
        .mem_we(mem_web),
        .mem_addr(mem_addrb),
        .mem_dw(mem_dib),
        .mem_dr(mem_dob)
    );

    // UART instance
    uart # (
        .P_BAUD_RATE(115200),
        .P_CLOCK_FREQUENCY(100_000_000 / CLK_DIVISION_FACTOR)
    ) uart_inst_0 (
        .clk(clk),
        .rst(rst),
        .data_stream_in(data_stream_in),
        .data_stream_in_stb(data_stream_in_stb),
        .data_stream_in_ack(data_stream_in_ack),
        .data_stream_out(data_stream_out),
        .data_stream_out_stb(data_stream_out_stb),
        .tx(rx),
        .rx(tx)
    );

    // Memory3 instance
    memory3 #(.ADDR_WIDTH(16)) memory3_inst_0 (
        .clk(clk),
        // Port a (accelerator)
        .ena(en),
        .wea(we),
        .addra(addr),
        .dia(dataW),
        .doa(dataR),
        // Port b (uart/controller)
        .enb(mem_enb),
        .web(mem_web),
        .addrb(mem_addrb),
        .dib(mem_dib),
        .dob(mem_dob)
    );

endmodule
