// -----------------------------------------------------------------------------
//
//  Title      :  Single port non-synthesizable ram
//             :
//  Developers :  Otto Westy Rasmussen <s203838@dtu.dk>
//             :
//  Purpose    :  Non-Synthesizable memory for task2.
//             :  Has single port for Accelerator + signal to triger saving of
//             :  the processed image to file.
//             :  File name for processed image is based on initial file name:
//             :     save_file_name = load_file_name & "_result.pgm"
//             :
//  Revision   :  02203 fall 2025 v.1.0
//
// -----------------------------------------------------------------------------


// Array type for memory storage, 32-bit words, 50688 entries.
typedef logic [31:0] ram_type[50688];


// Reads a PGM file and initializes the memory array (little-endian).
function automatic ram_type read_pgm_file(string load_file_name, ref int width, ref int height);
  string _line;
  string p2 = "P2";
  int fd;
  ram_type memory;

  // Check if file is provided
  fd = $fopen(load_file_name, "r");
  if (fd == 0) begin
    $display("Error: Cannot open file %s", load_file_name);
    $finish;
  end

  // Read and validate the PGM header
  $fgets(_line, fd);
  if (_line[0] != "P" | _line[1] != "2") begin
    $display("Error: Invalid file format (expected P2) got %s", _line);
    $finish;
  end

  // Skip comments
  do begin
    $fgets(_line, fd);
  end while (_line[0] == "#");

  // Read image width and height
  $sscanf(_line, "%d %d", width, height);
  if (width * height != 101376) begin
    $display("Error: Image size larger than expected (50688 pixels)");
    $finish;
  end

  // Read pixel data and pack into memory words (little-endian)
  for (int i = 0; i < (width * height)/4; i++) begin
    byte pixels [4];
    for (int j = 0; j < 4; j++) begin
        if ($fscanf(fd, "%d", pixels[j]) != 1) begin
            $display("Error: Not enough pixel data in file");
            $finish;
        end
    end
    memory[i] = {pixels[3], pixels[2], pixels[1], pixels[0]};
  end

  $fclose(fd);
  return memory;
endfunction


// Non-synthesizable single-port RAM for Accelerator. Supports reading/writing and dumping processed image to file.
module memory2 #(
    parameter string load_file_name = ""
) (
    input logic clk,         // Clock input
    input logic en,          // Enable signal for memory access
    input logic we,          // Write enable signal
    input logic [15:0] addr, // Address bus for memory
    input logic [31:0] dataW,// Data to write
    output logic [31:0] dataR,// Data read from memory
    input logic dump_image   // Signal to trigger image dump
);

  int width, height;
  localparam string save_file_name = {load_file_name.substr(0, load_file_name.len() - 5), "_result.pgm"};
  ram_type memory = read_pgm_file(load_file_name, width, height);

  // Single-Port RAM with Read First
  always_ff @(posedge clk) begin
    if (en) begin
      if (we) begin
        memory[addr] <= dataW;
      end
      dataR <= memory[addr];
    end
  end

  // Trigger dumping of processed image to file
  initial begin
    int fd;
    wait (dump_image) begin
        fd = $fopen (save_file_name, "w");
        $fwrite(fd, "P2\n");
        $fwrite(fd, "# Created by memory2 module\n");
        $fwrite(fd, "%0d %0d\n", width, height);
        $fwrite(fd, "255\n");
        for (int i = (width * height)/4; i < (width * height)/2; i++) begin
            for (int j = 0; j < 4; j++) begin
                $fwrite(fd, "%0d\n", memory[i][8*j+:8]);
            end
        end
        $fclose(fd);
        $display("Image dumped to %s", save_file_name);
        $finish;
    end
  end

endmodule
