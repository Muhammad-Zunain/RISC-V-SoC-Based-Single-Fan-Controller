`timescale 1ns/1ps

module tb_cpu_spi;

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
  logic spi_miso;
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

  // ============================================================
  // SPI Slave Model
  // ============================================================

  logic [7:0] slave_rx;
  logic       slave_valid;

  integer i;
  integer timeout;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  riscv_fan_soc #(
    .IMEM_WORDS(128),
    .DMEM_WORDS(16),
    .CFG_WORDS (16),

    .UART_DEFAULT_BAUD_DIV(32'd16),

    /*
     * Fast SPI clock for simulation.
     *
     * System clock = 100 MHz in this TB.
     *
     * SPI divisor = 2.
     */
    .SPI_DEFAULT_CLK_DIV(32'd2)
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
  // External SPI Slave
  // ============================================================
  //
  // Slave receives:
  //
  //      0xA5
  //
  // Slave returns:
  //
  //      0x3C
  //
  // SPI Mode:
  //
  //      Mode 0
  //      CPOL = 0
  //      CPHA = 0
  //      MSB first
  //
  // ============================================================

  spi_slave_model #(
    .RESPONSE(8'h3C)
  ) slave (
    .rst_i      (rst),

    .cs_n_i     (spi_cs_n),
    .sclk_i     (spi_sclk),
    .mosi_i     (spi_mosi),

    .miso_o     (spi_miso),

    .last_rx_o  (slave_rx),
    .rx_valid_o (slave_valid)
  );

  // ============================================================
  // Test
  // ============================================================

  initial begin

    /*
     * Wait for simulation RAM model initial blocks.
     */
    #1;

    // ==========================================================
    // Clear Instruction SRAM
    // ==========================================================

    for (i = 0; i < 128; i = i + 1) begin

      dut.u_imem.u_imem_ip.mem[i] =
        32'h0000_0013;        // NOP

    end

    // ==========================================================
    // Clear Data SRAM
    // ==========================================================

    for (i = 0; i < 16; i = i + 1) begin

      dut.u_dmem.u_dmem_ip.mem[i] =
        32'd0;

    end

    // ==========================================================
    // SPI Memory Map
    // ==========================================================
    //
    // SPI_BASE = 0x4000_2000
    //
    // +0x00 = TXDATA
    // +0x04 = CTRL
    // +0x08 = STATUS
    // +0x0C = RXDATA
    // +0x10 = CLK_DIV
    //
    // STATUS:
    //
    // bit 0 = busy
    // bit 1 = done
    // bit 2 = start_busy_error
    //
    // ==========================================================

    // ----------------------------------------------------------
    // 0:
    //
    // LUI x10,0x40002
    //
    // x10 = 0x4000_2000
    //     = SPI_BASE
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[0] =
      enc_u(
        20'h40002,
        10,
        7'b0110111
      );

    // ----------------------------------------------------------
    // 1:
    //
    // ADDI x1,x0,0xA5
    //
    // SPI transmit data.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[1] =
      enc_i(
        8'hA5,
        0,
        3'b000,
        1,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 2:
    //
    // SW x1,0(x10)
    //
    // SPI TXDATA = 0xA5
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[2] =
      enc_s(
        0,
        1,
        10,
        3'b010
      );

    // ----------------------------------------------------------
    // 3:
    //
    // ADDI x2,x0,1
    //
    // CTRL.START = 1
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[3] =
      enc_i(
        1,
        0,
        3'b000,
        2,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 4:
    //
    // SW x2,4(x10)
    //
    // Start SPI transaction.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[4] =
      enc_s(
        4,
        2,
        10,
        3'b010
      );

    // ==========================================================
    // Poll SPI STATUS
    // ==========================================================

    // ----------------------------------------------------------
    // 5:
    //
    // LW x3,8(x10)
    //
    // Read STATUS.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[5] =
      enc_i(
        8,
        10,
        3'b010,
        3,
        7'b0000011
      );

    // ----------------------------------------------------------
    // 6:
    //
    // ANDI x3,x3,2
    //
    // Isolate DONE bit.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[6] =
      enc_i(
        2,
        3,
        3'b111,
        3,
        7'b0010011
      );

    // ----------------------------------------------------------
    // 7:
    //
    // BEQ x3,x0,-8
    //
    // If DONE == 0:
    //
    //      go back to STATUS read.
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[7] =
      enc_b(
        -8,
        0,
        3,
        3'b000
      );

    // ----------------------------------------------------------
    // 8:
    //
    // LW x4,12(x10)
    //
    // Read SPI RXDATA.
    //
    // Expected:
    //
    //      x4 = 0x3C
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[8] =
      enc_i(
        12,
        10,
        3'b010,
        4,
        7'b0000011
      );

    // ----------------------------------------------------------
    // 9:
    //
    // LUI x11,0x10000
    //
    // x11 = 0x1000_0000
    //     = DMEM_BASE
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[9] =
      enc_u(
        20'h10000,
        11,
        7'b0110111
      );

    // ----------------------------------------------------------
    // 10:
    //
    // SW x4,0(x11)
    //
    // Save received SPI data into DMEM[0].
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[10] =
      enc_s(
        0,
        4,
        11,
        3'b010
      );

    // ----------------------------------------------------------
    // 11:
    //
    // EBREAK
    // ----------------------------------------------------------

    dut.u_imem.u_imem_ip.mem[11] =
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
      timeout < 1000
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    // ==========================================================
    // Timeout
    // ==========================================================

    if (timeout >= 1000) begin

      $fatal(
        1,
        "CPU-SPI timeout pc=%08x state=%0d",
        pc,
        state
      );

    end

    // ==========================================================
    // CPU should stop because of EBREAK
    // ==========================================================

    if (
      !trap ||
      cause !== 32'd3
    ) begin

      $fatal(
        1,
        "Expected EBREAK trap cause=3, got cause=%0d",
        cause
      );

    end

    // ==========================================================
    // Slave should have received 0xA5
    // ==========================================================

    if (!slave_valid) begin

      $fatal(
        1,
        "SPI slave did not receive a complete transfer"
      );

    end

    if (slave_rx !== 8'hA5) begin

      $fatal(
        1,
        "SPI slave expected MOSI=0xA5, got 0x%02x",
        slave_rx
      );

    end

    // ==========================================================
    // Master should have received 0x3C
    // ==========================================================

    if (dut.u_spi.rx_data_q !== 8'h3C) begin

      $fatal(
        1,
        "SPI master RX register expected 0x3C, got 0x%02x",
        dut.u_spi.rx_data_q
      );

    end

    // ==========================================================
    // CPU must save received value into Data SRAM
    // ==========================================================

    if (
      dut.u_dmem.u_dmem_ip.mem[0] !==
      32'h0000_003C
    ) begin

      $fatal(
        1,
        "SPI RX not saved to DMEM: got %08x",
        dut.u_dmem.u_dmem_ip.mem[0]
      );

    end

    // ==========================================================
    // Verify SPI TX register
    // ==========================================================

    if (dut.u_spi.tx_data_q !== 8'hA5) begin

      $fatal(
        1,
        "SPI TX register expected 0xA5, got 0x%02x",
        dut.u_spi.tx_data_q
      );

    end

    // ==========================================================
    // PASS
    // ==========================================================

    $display("");
    $display("========================================");
    $display("[PASS] tb_cpu_spi");
    $display("Master TX : 0x%02x", dut.u_spi.tx_data_q);
    $display("Slave RX  : 0x%02x", slave_rx);
    $display("Slave TX  : 0x3C");
    $display("Master RX : 0x%02x", dut.u_spi.rx_data_q);
    $display("DMEM[0]   : 0x%08x",
             dut.u_dmem.u_dmem_ip.mem[0]);
    $display("========================================");

    $finish;

  end

endmodule