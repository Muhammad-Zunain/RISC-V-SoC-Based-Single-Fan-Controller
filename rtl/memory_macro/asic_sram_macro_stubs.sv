// -----------------------------------------------------------------------------
// Abstract ASIC memory macro stubs.
//
// These are NOT behavioral memories and are NOT used by normal ModelSim RTL
// simulation. They are only for logic-synthesis integration when
// ASIC_USE_SRAM_MACROS is defined.
//
// For final P&R, replace these stubs with adapters around the real PDK SRAM/ROM
// macros and provide the corresponding .lib, .lef and .gds views.
// -----------------------------------------------------------------------------

(* black_box *)
module asic_imem_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic [9:0]  addr_i,
  output logic [31:0] rdata_o
);
endmodule

(* black_box *)
module asic_dmem_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic        we_i,
  input  logic [3:0]  wmask_i,
  input  logic [9:0]  addr_i,
  input  logic [31:0] wdata_i,
  output logic [31:0] rdata_o
);
endmodule

(* black_box *)
module asic_config_macro (
  input  logic        clk_i,
  input  logic        cs_i,
  input  logic        we_i,
  input  logic [3:0]  wmask_i,
  input  logic [7:0]  addr_i,
  input  logic [31:0] wdata_i,
  output logic [31:0] rdata_o
);
endmodule
