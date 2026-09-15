// -----------------------------------------------------------------------------
// ASIC memory macro adapters, active only when ASIC_USE_SRAM_MACROS is
// defined (Genus/Innovus flow). Not used by normal ModelSim RTL simulation.
//
// Physical macro: ram_256x16A (256 x 16, single-port synchronous, one WEN
// per whole 16-bit word, no per-byte write enable). See
// asic/genus/lib/ram_256x16A_*_syn.lib and docs/ASIC_MEMORY_MACRO_CONTRACT.md.
//
// Logical memory contract kept unchanged for asic_imem.sv / asic_dmem.sv /
// asic_config_mem.sv: 256 x 32, synchronous read, four byte write enables.
// Each logical memory is built from two ram_256x16A macros banked on data
// width (bits [15:0] and [31:16]). A macro's WEN is only ever asserted when
// its whole 16-bit half is being written; the caller (dmem_ip_wrapper /
// config_ip_wrapper) is responsible for turning a single-byte store into a
// read-modify-write full-word write before it reaches this adapter.
// -----------------------------------------------------------------------------

(* black_box *)
module ram_256x16A (
  input  logic        CLK,
  input  logic        CEN,
  input  logic        OEN,
  input  logic        WEN,
  input  logic [7:0]  A,
  input  logic [15:0] D,
  output logic [15:0] Q
);
endmodule

module asic_imem_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic [7:0]  addr_i,
  output logic [31:0] rdata_o
);

  logic [15:0] q_lo, q_hi;

  ram_256x16A u_lo (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (1'b1),
    .A   (addr_i),
    .D   (16'd0),
    .Q   (q_lo)
  );

  ram_256x16A u_hi (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (1'b1),
    .A   (addr_i),
    .D   (16'd0),
    .Q   (q_hi)
  );

  assign rdata_o = {q_hi, q_lo};

endmodule

module asic_dmem_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic        we_i,
  input  logic [3:0]  wmask_i,
  input  logic [7:0]  addr_i,
  input  logic [31:0] wdata_i,
  output logic [31:0] rdata_o
);

  logic lo_we, hi_we;
  logic [15:0] q_lo, q_hi;

  assign lo_we = we_i && wmask_i[1] && wmask_i[0];
  assign hi_we = we_i && wmask_i[3] && wmask_i[2];

  ram_256x16A u_lo (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (~lo_we),
    .A   (addr_i),
    .D   (wdata_i[15:0]),
    .Q   (q_lo)
  );

  ram_256x16A u_hi (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (~hi_we),
    .A   (addr_i),
    .D   (wdata_i[31:16]),
    .Q   (q_hi)
  );

  assign rdata_o = {q_hi, q_lo};

endmodule

module asic_config_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic        we_i,
  input  logic [3:0]  wmask_i,
  input  logic [7:0]  addr_i,
  input  logic [31:0] wdata_i,
  output logic [31:0] rdata_o
);

  logic lo_we, hi_we;
  logic [15:0] q_lo, q_hi;

  assign lo_we = we_i && wmask_i[1] && wmask_i[0];
  assign hi_we = we_i && wmask_i[3] && wmask_i[2];

  ram_256x16A u_lo (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (~lo_we),
    .A   (addr_i),
    .D   (wdata_i[15:0]),
    .Q   (q_lo)
  );

  ram_256x16A u_hi (
    .CLK (clk_i),
    .CEN (~cs_i),
    .OEN (1'b0),
    .WEN (~hi_we),
    .A   (addr_i),
    .D   (wdata_i[31:16]),
    .Q   (q_hi)
  );

  assign rdata_o = {q_hi, q_lo};

endmodule
