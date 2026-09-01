`timescale 1ns/1ps

module tb_cpu_memory;

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
  logic uart_rx = 1'b1;

  logic spi_sclk;
  logic spi_mosi;
  logic spi_miso = 1'b0;
  logic spi_cs_n;

  // ============================================================
  // Debug
  // ============================================================

  logic [31:0] pc;
  logic [31:0] instr;
  logic [31:0] cause;

  logic        halted;
  logic        trap;
  logic [3:0]  state;

  integer i;
  integer timeout;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  riscv_fan_soc #(
    .IMEM_WORDS(64),
    .DMEM_WORDS(32),
    .CFG_WORDS (16),

    // Fast UART value for simulation
    .UART_DEFAULT_BAUD_DIV(32'd16)
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
  // Test
  // ============================================================

  initial begin

    /*
     * Wait until simulation-only IP models have completed their
     * own initial blocks.
     */
    #1;

    // ==========================================================
    // Clear Instruction SRAM
    // ==========================================================
    //
    // OLD hierarchy:
    //
    //   dut.u_imem.mem[]
    //
    // NEW hierarchy:
    //
    //   dut.u_imem.u_imem_ip.mem[]
    //
    // ==========================================================

    for (i = 0; i < 64; i = i + 1)
      dut.u_imem.u_imem_ip.mem[i] =
        32'h0000_0013;            // NOP

    // ==========================================================
    // Clear Data SRAM
    // ==========================================================

    for (i = 0; i < 32; i = i + 1)
      dut.u_dmem.u_dmem_ip.mem[i] =
        32'd0;

    // ==========================================================
    // Program
    // ==========================================================

    /*
     * LUI x10,0x10000
     *
     * x10 = 0x1000_0000
     *
     * This is DMEM_BASE.
     */
    dut.u_imem.u_imem_ip.mem[0] =
      enc_u(
        20'h10000,
        10,
        7'b0110111
      );

    /*
     * ADDI x1,x0,52
     *
     * x1 = 52
     */
    dut.u_imem.u_imem_ip.mem[1] =
      enc_i(
        52,
        0,
        3'b000,
        1,
        7'b0010011
      );

    /*
     * SW x1,0(x10)
     *
     * DMEM[0] = 52
     */
    dut.u_imem.u_imem_ip.mem[2] =
      enc_s(
        0,
        1,
        10,
        3'b010
      );

    /*
     * LW x2,0(x10)
     *
     * x2 = 52
     */
    dut.u_imem.u_imem_ip.mem[3] =
      enc_i(
        0,
        10,
        3'b010,
        2,
        7'b0000011
      );

    /*
     * ADDI x3,x0,-1
     *
     * x3 = 0xFFFF_FFFF
     */
    dut.u_imem.u_imem_ip.mem[4] =
      enc_i(
        -1,
        0,
        3'b000,
        3,
        7'b0010011
      );

    /*
     * SB x3,4(x10)
     *
     * Only byte 0 of DMEM word 1 is written:
     *
     * DMEM[1] = 0x000000FF
     */
    dut.u_imem.u_imem_ip.mem[5] =
      enc_s(
        4,
        3,
        10,
        3'b000
      );

    /*
     * LBU x4,4(x10)
     *
     * x4 = 0x000000FF
     */
    dut.u_imem.u_imem_ip.mem[6] =
      enc_i(
        4,
        10,
        3'b100,
        4,
        7'b0000011
      );

    /*
     * EBREAK
     *
     * End program with breakpoint trap.
     */
    dut.u_imem.u_imem_ip.mem[7] =
      32'h0010_0073;

    // ==========================================================
    // Reset
    // ==========================================================

    repeat (4)
      @(posedge clk);

    @(negedge clk);

    rst = 1'b0;

    // ==========================================================
    // Wait for EBREAK
    // ==========================================================

    timeout = 0;

    while (
      !halted &&
      timeout < 300
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    // ==========================================================
    // Checks
    // ==========================================================

    if (timeout >= 300)
      $fatal(
        1,
        "CPU-memory timeout pc=%08x state=%0d",
        pc,
        state
      );

    /*
     * EBREAK exception cause = 3
     */
    if (
      !trap ||
      cause !== 32'd3
    )
      $fatal(
        1,
        "Expected EBREAK cause=3, got cause=%0d",
        cause
      );

    // ----------------------------------------------------------
    // SW check
    // ----------------------------------------------------------

    if (
      dut.u_dmem.u_dmem_ip.mem[0] !==
      32'd52
    )
      $fatal(
        1,
        "DMEM SW failed: mem[0]=%08x",
        dut.u_dmem.u_dmem_ip.mem[0]
      );

    // ----------------------------------------------------------
    // LW check
    // ----------------------------------------------------------

    if (
      dut.u_core.u_regfile.regs[2] !==
      32'd52
    )
      $fatal(
        1,
        "DMEM LW failed: x2=%08x",
        dut.u_core.u_regfile.regs[2]
      );

    // ----------------------------------------------------------
    // SB byte-enable check
    // ----------------------------------------------------------

    if (
      dut.u_dmem.u_dmem_ip.mem[1] !==
      32'h0000_00FF
    )
      $fatal(
        1,
        "DMEM SB failed: mem[1]=%08x",
        dut.u_dmem.u_dmem_ip.mem[1]
      );

    // ----------------------------------------------------------
    // LBU check
    // ----------------------------------------------------------

    if (
      dut.u_core.u_regfile.regs[4] !==
      32'h0000_00FF
    )
      $fatal(
        1,
        "LBU integration failed: x4=%08x",
        dut.u_core.u_regfile.regs[4]
      );

    // ----------------------------------------------------------
    // x0 must remain zero
    // ----------------------------------------------------------

    if (
      dut.u_core.u_regfile.regs[0] !==
      32'd0
    )
      $fatal(
        1,
        "x0 register corrupted"
      );

    // ==========================================================
    // PASS
    // ==========================================================

    $display("");
    $display("========================================");
    $display("[PASS] tb_cpu_memory");
    $display("SW  : DMEM[0] = %0d",
             dut.u_dmem.u_dmem_ip.mem[0]);
    $display("LW  : x2      = %0d",
             dut.u_core.u_regfile.regs[2]);
    $display("SB  : DMEM[1] = %08x",
             dut.u_dmem.u_dmem_ip.mem[1]);
    $display("LBU : x4      = %08x",
             dut.u_core.u_regfile.regs[4]);
    $display("========================================");

    $finish;

  end

endmodule