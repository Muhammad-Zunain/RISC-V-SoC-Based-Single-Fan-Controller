`timescale 1ns/1ps

module tb_cpu_pwm;

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
  // Debug signals
  // ============================================================

  logic [31:0] pc;
  logic [31:0] instr;
  logic [31:0] cause;

  logic        halted;
  logic        trap;
  logic [3:0]  state;

  integer i;
  integer timeout;
  integer highs;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  riscv_fan_soc #(
    .IMEM_WORDS(64),
    .DMEM_WORDS(16),
    .CFG_WORDS (16),

    .PWM_DEFAULT_PERIOD(32'd100),

    // Small divisor for simulation only.
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
  // Main Test
  // ============================================================

  initial begin

    /*
     * Allow the RAM simulation model initial block to complete
     * before replacing its contents with this directed program.
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
        32'h0000_0013;  // NOP

    end

    // ==========================================================
    // CPU PROGRAM
    // ==========================================================

    /*
     * PWM memory map:
     *
     * Base:
     *   0x4000_0000
     *
     * Offset 0x00 = CTRL
     * Offset 0x04 = PERIOD
     * Offset 0x08 = DUTY
     */

    // ----------------------------------------------------------
    // 0:
    //
    // LUI x10,0x40000
    //
    // x10 = 0x4000_0000
    //      = PWM_BASE
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[0] =
      enc_u(
        20'h40000,
        10,
        7'b0110111
      );

    // ----------------------------------------------------------
    // 1:
    //
    // ADDI x2,x0,100
    //
    // x2 = PWM period = 100 clocks
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[1] =
      enc_i(
        100,
        0,
        3'b000,
        2,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 2:
    //
    // SW x2,4(x10)
    //
    // PWM_PERIOD = 100
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[2] =
      enc_s(
        4,
        2,
        10,
        3'b010
      );

    // ----------------------------------------------------------
    // 3:
    //
    // ADDI x3,x0,30
    //
    // x3 = PWM duty = 30 clocks
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[3] =
      enc_i(
        30,
        0,
        3'b000,
        3,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 4:
    //
    // SW x3,8(x10)
    //
    // PWM_DUTY = 30
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[4] =
      enc_s(
        8,
        3,
        10,
        3'b010
      );

    // ----------------------------------------------------------
    // 5:
    //
    // ADDI x1,x0,1
    //
    // x1 = PWM enable
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[5] =
      enc_i(
        1,
        0,
        3'b000,
        1,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 6:
    //
    // SW x1,0(x10)
    //
    // PWM_CTRL.enable = 1
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[6] =
      enc_s(
        0,
        1,
        10,
        3'b010
      );

    // ----------------------------------------------------------
    // 7:
    //
    // JAL x0,0
    //
    // Infinite loop.
    // CPU remains alive after configuring PWM.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[7] =
      enc_j(
        0,
        0
      );

    // ==========================================================
    // RESET
    // ==========================================================

    repeat (4)
      @(posedge clk);

    @(negedge clk);

    rst = 1'b0;

    // ==========================================================
    // Wait until CPU has programmed PWM
    // ==========================================================

    timeout = 0;

    while (
      (
        dut.u_pwm.enable_q !== 1'b1 ||
        dut.u_pwm.period_q !== 32'd100 ||
        dut.u_pwm.duty_q   !== 32'd30
      )
      &&
      timeout < 200
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    if (timeout >= 200) begin

      $fatal(
        1,
        "CPU did not program PWM: enable=%0d period=%0d duty=%0d pc=%08x state=%0d",
        dut.u_pwm.enable_q,
        dut.u_pwm.period_q,
        dut.u_pwm.duty_q,
        pc,
        state
      );

    end

    // ==========================================================
    // Check programmed register values
    // ==========================================================

    if (dut.u_pwm.enable_q !== 1'b1)
      $fatal(
        1,
        "PWM enable register incorrect"
      );

    if (dut.u_pwm.period_q !== 32'd100)
      $fatal(
        1,
        "PWM period expected 100 got %0d",
        dut.u_pwm.period_q
      );

    if (dut.u_pwm.duty_q !== 32'd30)
      $fatal(
        1,
        "PWM duty expected 30 got %0d",
        dut.u_pwm.duty_q
      );

    // ==========================================================
    // Ensure CPU did not generate a trap
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
    // PWM Duty-Cycle Verification
    // ==========================================================
    //
    // Period = 100 clocks
    // Duty   = 30 clocks
    //
    // Therefore:
    //
    //      duty = 30 / 100
    //           = 30%
    //
    // Measure 500 clocks:
    //
    //      500 / 100 = 5 complete PWM periods
    //
    // Expected HIGH samples:
    //
    //      5 * 30 = 150
    //
    // ==========================================================

    /*
     * Allow PWM to operate for one complete period before
     * beginning the measurement.
     */
    repeat (100)
      @(posedge clk);

    highs = 0;

    for (i = 0; i < 500; i = i + 1) begin

      @(negedge clk);

      if (pwm)
        highs = highs + 1;

    end

    // ==========================================================
    // Verify exact 30% output
    // ==========================================================

    if (highs != 150) begin

      $fatal(
        1,
        "CPU-PWM expected 30%% duty: expected 150 HIGH clocks, got %0d",
        highs
      );

    end

    // ==========================================================
    // Final trap check
    // ==========================================================

    if (trap || halted) begin

      $fatal(
        1,
        "CPU trapped while PWM was running: cause=%0d",
        cause
      );

    end

    // ==========================================================
    // PASS
    // ==========================================================

    $display("");
    $display("========================================");
    $display("[PASS] tb_cpu_pwm");
    $display("PWM enable : %0d", dut.u_pwm.enable_q);
    $display("PWM period : %0d clocks", dut.u_pwm.period_q);
    $display("PWM duty   : %0d clocks", dut.u_pwm.duty_q);
    $display("HIGH count : %0d / 500", highs);
    $display("Duty cycle : 30%%");
    $display("========================================");

    $finish;

  end

endmodule