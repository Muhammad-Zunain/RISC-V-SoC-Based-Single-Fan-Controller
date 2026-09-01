module asic_imem #(
  parameter integer WORDS  = 1024,
  parameter integer ADDR_W = $clog2(WORDS),
  parameter INIT_FILE      = "firmware/soc_demo.hex"
) (
  input  logic              clk_i,
  input  logic              en_i,
  input  logic [ADDR_W-1:0] addr_i,
  output logic [31:0]       rdata_o
);

`ifdef ASIC_USE_SRAM_MACROS
  // Final ASIC flow: this abstract macro is replaced/bound to the
  // technology-specific ROM/SRAM macro for the selected PDK.
  asic_imem_macro u_macro (
    .clk_i   (clk_i),
    .cs_i    (en_i),
    .addr_i  (addr_i[9:0]),
    .rdata_o (rdata_o)
  );
`else
  // RTL/ModelSim reference model. This array is intentionally visible so
  // directed testbenches can preload instructions hierarchically.
  logic [31:0] mem [0:WORDS-1];
  integer i;

  initial begin
    for (i = 0; i < WORDS; i = i + 1)
      mem[i] = 32'h0000_0013; // RV32I NOP

    if (INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  // One-cycle synchronous read.
  always @(posedge clk_i) begin
    if (en_i)
      rdata_o <= mem[addr_i];
  end
`endif

endmodule
