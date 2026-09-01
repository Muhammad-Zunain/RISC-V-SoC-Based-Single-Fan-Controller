// -----------------------------------------------------------------------------
// Simulation-only stand-ins for the three Quartus-generated RAM IP variations.
// DO NOT compile this file together with the actual generated IP simulation HDL.
// It exists so the multicycle RTL can be tested before the IP Catalog step.
// ----------------------------------------------------------------------------

module imem_ip (
  input  logic [9:0]  address,
  input  logic        clock,
  input  logic [31:0] data,
  input  logic        wren,
  output logic [31:0] q
);
  logic [31:0] mem [0:1023];
  integer i;
  initial begin
    for (i = 0; i < 1024; i = i + 1)
      mem[i] = 32'h0000_0013;
    $readmemh("firmware/soc_demo.hex", mem);
  end
  always @(posedge clock) begin
    if (wren)
      mem[address] <= data;
    q <= mem[address];
  end
endmodule

module dmem_ip (
  input  logic [9:0]  address,
  input  logic [3:0]  byteena,
  input  logic        clock,
  input  logic [31:0] data,
  input  logic        wren,
  output logic [31:0] q
);
  logic [31:0] mem [0:1023];
  integer i;
  initial begin
    for (i = 0; i < 1024; i = i + 1)
      mem[i] = 32'd0;
  end
  always @(posedge clock) begin
    if (wren) begin
      if (byteena[0]) mem[address][7:0]   <= data[7:0];
      if (byteena[1]) mem[address][15:8]  <= data[15:8];
      if (byteena[2]) mem[address][23:16] <= data[23:16];
      if (byteena[3]) mem[address][31:24] <= data[31:24];
    end
    q <= mem[address];
  end
endmodule

module cfg_ip (
  input  logic [7:0]  address,
  input  logic [3:0]  byteena,
  input  logic        clock,
  input  logic [31:0] data,
  input  logic        wren,
  output logic [31:0] q
);
  logic [31:0] mem [0:255];
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1)
      mem[i] = 32'd0;
    $readmemh("firmware/config_demo.hex", mem);
  end
  always @(posedge clock) begin
    if (wren) begin
      if (byteena[0]) mem[address][7:0]   <= data[7:0];
      if (byteena[1]) mem[address][15:8]  <= data[15:8];
      if (byteena[2]) mem[address][23:16] <= data[23:16];
      if (byteena[3]) mem[address][31:24] <= data[31:24];
    end
    q <= mem[address];
  end
endmodule
