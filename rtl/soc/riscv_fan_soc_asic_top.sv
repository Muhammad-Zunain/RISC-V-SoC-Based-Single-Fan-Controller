module riscv_fan_soc_asic_top (
  input  logic clk_i,
  input  logic reset_n_i,

  output logic pwm_o,

  output logic uart_tx_o,
  input  logic uart_rx_i,

  output logic spi_sclk_o,
  output logic spi_mosi_o,
  input  logic spi_miso_i,
  output logic spi_cs_n_o,

  output logic status_halted_o,
  output logic status_trap_o,

  // Debug/bring-up observability ports. These are real primary outputs so
  // that the CPU debug bus stays reachable and is not deleted by Genus as
  // unobservable/unloaded logic during syn_generic/syn_map/syn_opt.
  output logic [31:0] debug_pc_o,
  output logic [31:0] debug_instr_o,
  output logic [31:0] debug_trap_cause_o,
  output logic [3:0]  debug_state_o
);

  // Asynchronous assertion, synchronous deassertion reset synchronizer.
  logic [1:0] rst_sync_q;
  logic       rst_i;

  always_ff @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i)
      rst_sync_q <= 2'b11;
    else
      rst_sync_q <= {rst_sync_q[0], 1'b0};
  end

  assign rst_i = rst_sync_q[1];

  riscv_fan_soc #(
    .IMEM_WORDS(256),
    .DMEM_WORDS(256),
    .CFG_WORDS (256),

    // These files are used only by RTL simulation when the behavioral memory
    // backend is active. They are ignored when ASIC_USE_SRAM_MACROS is defined.
    .IMEM_INIT_FILE("firmware/soc_demo.hex"),
    .CFG_INIT_FILE ("firmware/config_demo.hex"),

    .PWM_DEFAULT_PERIOD    (32'd100),
    .UART_DEFAULT_BAUD_DIV (32'd434),
    .SPI_DEFAULT_CLK_DIV   (32'd25)
  ) u_soc (
    .clk_i                  (clk_i),
    .rst_i                  (rst_i),

    .pwm_o                  (pwm_o),

    .uart_tx_o              (uart_tx_o),
    .uart_rx_i              (uart_rx_i),

    .spi_sclk_o             (spi_sclk_o),
    .spi_mosi_o             (spi_mosi_o),
    .spi_miso_i             (spi_miso_i),
    .spi_cs_n_o             (spi_cs_n_o),

    .debug_pc_o             (debug_pc_o),
    .debug_instr_o          (debug_instr_o),
    .debug_halted_o         (status_halted_o),
    .debug_trap_o           (status_trap_o),
    .debug_trap_cause_o     (debug_trap_cause_o),
    .debug_state_o          (debug_state_o)
  );

endmodule
