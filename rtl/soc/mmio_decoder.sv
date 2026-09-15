module mmio_decoder #(
  parameter integer DMEM_WORDS = 256,
  parameter integer CFG_WORDS  = 256
) (
  input  logic        valid_i,
  input  logic [31:0] addr_i,
  output logic        sel_dmem_o,
  output logic        sel_cfg_o,
  output logic        sel_pwm_o,
  output logic        sel_uart_o,
  output logic        sel_spi_o,
  output logic        fault_o
);
  import soc_pkg::*;

  localparam logic [31:0] DMEM_END = DMEM_BASE + (DMEM_WORDS * 4);
  localparam logic [31:0] CFG_END  = CFG_BASE  + (CFG_WORDS  * 4);

  always_comb begin
    sel_dmem_o = valid_i && (addr_i >= DMEM_BASE) && (addr_i < DMEM_END);
    sel_cfg_o  = valid_i && (addr_i >= CFG_BASE)  && (addr_i < CFG_END);
    sel_pwm_o  = valid_i && ((addr_i & 32'hffff_f000) == PWM_BASE);
    sel_uart_o = valid_i && ((addr_i & 32'hffff_f000) == UART_BASE);
    sel_spi_o  = valid_i && ((addr_i & 32'hffff_f000) == SPI_BASE);
    fault_o    = valid_i && !(sel_dmem_o || sel_cfg_o || sel_pwm_o || sel_uart_o || sel_spi_o);
  end
endmodule
