`timescale 1ns/1ps

module tb_cpu_uart;

  // ============================================================
  // Simulation UART baud divisor
  // ============================================================

  localparam logic [31:0] DIV = 32'd16;

  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk = 1'b0;
  logic rst = 1'b1;

  always #5 clk = ~clk;

  // ============================================================
  // SoC external signals
  // ============================================================

  logic pwm;

  logic uart_tx;
  logic uart_rx = 1'b1;   // UART idle level is HIGH

  logic spi_sclk;
  logic spi_mosi;
  logic spi_miso = 1'b0;
  logic spi_cs_n;

  // ============================================================
  // Debug signals
  // ============================================================

  logic [31:0] pc;
  logic [31:0] instr;
  logic [31:0] cause;

  logic        halted;
  logic        trap;
  logic [3:0]  state;

  // ============================================================
  // UART Terminal Model Outputs
  // ============================================================

  logic [7:0] byte_seen;
  logic       byte_valid;
  logic       frame_error;

  integer i;
  integer timeout;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  riscv_fan_soc #(
    .IMEM_WORDS(64),
    .DMEM_WORDS(16),
    .CFG_WORDS (16),

    // Use a small divisor to make simulation fast.
    .UART_DEFAULT_BAUD_DIV(DIV)
  ) dut (
    .clk_i                  (clk),
    .rst_i                  (rst),

    .pwm_o                  (pwm),

    .uart_tx_o              (uart_tx),
    .uart_rx_i              (uart_rx),

    .spi_sclk_o             (spi_sclk),
    .spi_mosi_o             (spi_mosi),
    .spi_miso_i             (spi_miso),
    .spi_cs_n_o             (spi_cs_n),

    .debug_pc_o             (pc),
    .debug_instr_o          (instr),
    .debug_halted_o         (halted),
    .debug_trap_o           (trap),
    .debug_trap_cause_o     (cause),
    .debug_state_o          (state)
  );

  // ============================================================
  // UART Terminal Model
  // ============================================================
  //
  // This behaves like an external serial terminal.
  //
  // It receives whatever the SoC transmits on uart_tx.
  //
  // ============================================================

  uart_terminal_model #(
    .BAUD_DIV(DIV)
  ) term (
    .clk_i              (clk),
    .rst_i              (rst),

    .serial_i           (uart_tx),

    .last_byte_o        (byte_seen),
    .byte_valid_o       (byte_valid),
    .framing_error_o    (frame_error)
  );

  // ============================================================
  // Test
  // ============================================================

  initial begin

    /*
     * Allow the simulation RAM model initial block to finish
     * before overwriting IMEM with this directed test program.
     */
    #1;

    // ==========================================================
    // Clear Instruction SRAM
    // ==========================================================
    //
    // OLD:
    //
    //   dut.u_imem.mem[]
    //
    // NEW:
    //
    //   dut.u_imem.u_imem_ip.mem[]
    //
    // ==========================================================

    for (i = 0; i < 64; i = i + 1) begin

      dut.u_imem.u_imem_ip.mem[i] =
        32'h0000_0013;      // RV32I NOP

    end

    // ==========================================================
    // CPU Program
    // ==========================================================
    //
    // UART memory map:
    //
    //   UART_BASE   = 0x4000_1000
    //
    //   +0x000 = TXDATA
    //   +0x004 = RXDATA
    //   +0x008 = STATUS
    //   +0x00C = BAUD
    //
    // Program will send:
    //
    //        0x48 = ASCII 'H'
    //
    // ==========================================================

    // ----------------------------------------------------------
    // Instruction 0
    //
    // LUI x10,0x40001
    //
    // x10 = 0x4000_1000
    //
    //      = UART_BASE
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[0] =
      enc_u(
        20'h40001,
        10,
        7'b0110111
      );

    // ----------------------------------------------------------
    // Instruction 1
    //
    // ADDI x1,x0,0x48
    //
    // x1 = 0x48
    //    = ASCII 'H'
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[1] =
      enc_i(
        8'h48,
        0,
        3'b000,
        1,
        7'b0010011
      );

    // ----------------------------------------------------------
    // Instruction 2
    //
    // SW x1,0(x10)
    //
    // Write:
    //
    //   0x48 → UART TXDATA
    //
    // This starts UART transmission.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[2] =
      enc_s(
        0,
        1,
        10,
        3'b010
      );

    // ----------------------------------------------------------
    // Instruction 3
    //
    // JAL x0,0
    //
    // Infinite loop after UART write.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[3] =
      enc_j(
        0,
        0
      );

    // ==========================================================
    // Reset
    // ==========================================================

    repeat (4)
      @(posedge clk);

    @(negedge clk);

    rst = 1'b0;

    // ==========================================================
    // Wait for external UART terminal to receive a byte
    // ==========================================================

    timeout = 0;

    while (
      !byte_valid &&
      timeout < 500
    ) begin

      @(posedge clk);

      timeout = timeout + 1;

    end

    // ==========================================================
    // Timeout Check
    // ==========================================================

    if (timeout >= 500) begin

      $fatal(
        1,
        "CPU-UART timeout: pc=%08x state=%0d",
        pc,
        state
      );

    end

    // ==========================================================
    // Framing Check
    // ==========================================================

    if (frame_error) begin

      $fatal(
        1,
        "CPU-UART framing error"
      );

    end

    // ==========================================================
    // Received Byte Check
    // ==========================================================

    if (byte_seen !== 8'h48) begin

      $fatal(
        1,
        "CPU-UART expected 0x48 ('H'), got 0x%02x",
        byte_seen
      );

    end

    // ==========================================================
    // Check UART register captured correct TX byte
    // ==========================================================

    if (dut.u_uart.tx_data_q !== 8'h48) begin

      $fatal(
        1,
        "UART TXDATA register expected 0x48, got 0x%02x",
        dut.u_uart.tx_data_q
      );

    end

    // ==========================================================
    // CPU should not trap
    // ==========================================================

    if (trap || halted) begin

      $fatal(
        1,
        "Unexpected CPU trap: cause=%0d pc=%08x state=%0d",
        cause,
        pc,
        state
      );

    end

    // ==========================================================
    // PASS
    // ==========================================================

    $display("");
    $display("========================================");
    $display("[PASS] tb_cpu_uart");
    $display("UART TX byte : 0x%02x", byte_seen);
    $display("ASCII        : H");
    $display("Baud divisor : %0d", DIV);
    $display("Frame error  : %0d", frame_error);
    $display("========================================");

    $finish;

  end

endmodule