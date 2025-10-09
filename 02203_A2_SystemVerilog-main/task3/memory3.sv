// -----------------------------------------------------------------------------
//
//  Title      :  Dual port block ram memory module
//             :
//  Developers :  Otto Westy Rasmussen <s203838@dtu.dk>
//             :
//  Purpose    :  Dual-Port Block ram with Two Write Ports
//             :  Modelized with a Shared Variable. Little-endian.
//             :  Data size is 32 bits, memory size is 2^ADDR_SIZE
//             :
//  Revision   :  02203 fall 2025 v.1.0
//
// -----------------------------------------------------------------------------

module memory3 #(
    parameter ADDR_WIDTH = 16
) (
    input logic clk,
    // port a
    input logic ena,
    input logic wea,
    input logic [ADDR_WIDTH-1:0] addra,
    input logic [31:0] dia,
    output logic [31:0] doa,
    // port b
    input logic enb,
    input logic web,
    input logic [ADDR_WIDTH-1:0] addrb,
    input logic [31:0] dib,
    output logic [31:0] dob
);

    logic [31:0] ram [2 ** ADDR_WIDTH];

    always_ff @(posedge clk) begin
        if (ena) begin
            if (wea) begin
                ram[addra] <= dia;
            end else begin
                doa <= ram[addra];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (enb) begin
            if (web) begin
                ram[addrb] <= dib;
            end else begin
                dob <= ram[addrb];
            end
        end
    end

endmodule
