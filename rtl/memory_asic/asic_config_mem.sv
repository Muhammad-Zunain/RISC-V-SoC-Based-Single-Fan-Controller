module asic_config_mem #(
  parameter integer WORDS  = 256,
  parameter integer ADDR_W = $clog2(WORDS),
  parameter INIT_FILE      = "firmware/config_demo.hex"
) (
  input  logic              clk_i,
  input  logic              en_i,
  input  logic              we_i,
  input  logic [3:0]        wmask_i,
  input  logic [ADDR_W-1:0] addr_i,
  input  logic [31:0]       wdata_i,
  output logic [31:0]       rdata_o
);

`ifdef ASIC_USE_SRAM_MACROS
  // Final ASIC path. Logical contract matches DMEM: 256x32 1RW memory,
  // one-cycle read, four byte write enables.
  asic_config_macro u_macro (
    .clk_i   (clk_i),
    .cs_i    (en_i),
    .we_i    (we_i),
    .wmask_i (wmask_i),
    .addr_i  (addr_i),
    .wdata_i (wdata_i),
    .rdata_o (rdata_o)
  );
`else
  // RTL/ModelSim reference model. The config table can be initialized from
  // a HEX file or overwritten directly by a directed testbench.
  logic [31:0] mem [0:WORDS-1];
  integer i;

  initial begin
    for (i = 0; i < WORDS; i = i + 1)
      mem[i] = 32'd0;

    if (INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  always @(posedge clk_i) begin
    if (en_i) begin
      rdata_o <= mem[addr_i];

      if (we_i) begin
        if (wmask_i[0]) mem[addr_i][7:0]   <= wdata_i[7:0];
        if (wmask_i[1]) mem[addr_i][15:8]  <= wdata_i[15:8];
        if (wmask_i[2]) mem[addr_i][23:16] <= wdata_i[23:16];
        if (wmask_i[3]) mem[addr_i][31:24] <= wdata_i[31:24];
      end
    end
  end
`endif

endmodule
