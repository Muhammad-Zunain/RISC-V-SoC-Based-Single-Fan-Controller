package soc_pkg;
  // --------------------------------------------------------------------------
  // Global memory map
  // --------------------------------------------------------------------------
  localparam logic [31:0] RESET_PC  = 32'h0000_0000;
  localparam logic [31:0] IMEM_BASE = 32'h0000_0000;
  localparam logic [31:0] DMEM_BASE = 32'h1000_0000;
  localparam logic [31:0] CFG_BASE  = 32'h2000_0000;
  localparam logic [31:0] PWM_BASE  = 32'h4000_0000;
  localparam logic [31:0] UART_BASE = 32'h4000_1000;
  localparam logic [31:0] SPI_BASE  = 32'h4000_2000;

  // PWM register offsets.
  localparam logic [11:0] PWM_CTRL_OFS   = 12'h000;
  localparam logic [11:0] PWM_PERIOD_OFS = 12'h004;
  localparam logic [11:0] PWM_DUTY_OFS   = 12'h008;
  localparam logic [11:0] PWM_COUNT_OFS  = 12'h00c;

  // UART register offsets.
  localparam logic [11:0] UART_TXDATA_OFS = 12'h000;
  localparam logic [11:0] UART_RXDATA_OFS = 12'h004;
  localparam logic [11:0] UART_STATUS_OFS = 12'h008;
  localparam logic [11:0] UART_BAUD_OFS   = 12'h00c;

  // SPI register offsets.
  localparam logic [11:0] SPI_TXDATA_OFS = 12'h000;
  localparam logic [11:0] SPI_CTRL_OFS   = 12'h004;
  localparam logic [11:0] SPI_STATUS_OFS = 12'h008;
  localparam logic [11:0] SPI_RXDATA_OFS = 12'h00c;
  localparam logic [11:0] SPI_CLKDIV_OFS = 12'h010;

  // ALU operations.
  localparam logic [3:0] ALU_ADD  = 4'd0;
  localparam logic [3:0] ALU_SUB  = 4'd1;
  localparam logic [3:0] ALU_SLL  = 4'd2;
  localparam logic [3:0] ALU_SLT  = 4'd3;
  localparam logic [3:0] ALU_SLTU = 4'd4;
  localparam logic [3:0] ALU_XOR  = 4'd5;
  localparam logic [3:0] ALU_SRL  = 4'd6;
  localparam logic [3:0] ALU_SRA  = 4'd7;
  localparam logic [3:0] ALU_OR   = 4'd8;
  localparam logic [3:0] ALU_AND  = 4'd9;

  // Immediate formats.
  localparam logic [2:0] IMM_I = 3'd0;
  localparam logic [2:0] IMM_S = 3'd1;
  localparam logic [2:0] IMM_B = 3'd2;
  localparam logic [2:0] IMM_U = 3'd3;
  localparam logic [2:0] IMM_J = 3'd4;

  // Writeback sources.
  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // Simplified trap/stop causes. The core stops on an exception rather than
  // implementing mtvec/mepc/mcause CSRs; cause values match RISC-V numbering.
  localparam logic [31:0] CAUSE_INSTR_MISALIGNED = 32'd0;
  localparam logic [31:0] CAUSE_INSTR_ACCESS     = 32'd1;
  localparam logic [31:0] CAUSE_ILLEGAL_INSTR    = 32'd2;
  localparam logic [31:0] CAUSE_BREAKPOINT       = 32'd3;
  localparam logic [31:0] CAUSE_LOAD_MISALIGNED  = 32'd4;
  localparam logic [31:0] CAUSE_LOAD_ACCESS      = 32'd5;
  localparam logic [31:0] CAUSE_STORE_MISALIGNED = 32'd6;
  localparam logic [31:0] CAUSE_STORE_ACCESS     = 32'd7;
  localparam logic [31:0] CAUSE_ECALL            = 32'd11;
endpackage
