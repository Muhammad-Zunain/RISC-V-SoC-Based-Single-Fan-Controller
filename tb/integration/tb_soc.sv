`timescale 1ns/1ps

module tb_soc;

  // ============================================================
  // Simulation Parameters
  // ============================================================

  localparam integer UART_DIV = 16;

  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk = 1'b0;
  logic rst = 1'b1;

  always #5 clk = ~clk;

  // ============================================================
  // SoC External Signals
  // ============================================================

  logic pwm;

  logic uart_tx;
  logic uart_rx = 1'b1;

  logic sclk;
  logic mosi;
  logic miso;
  logic csn;

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

  logic [7:0] spi_slave_rx;
  logic       spi_slave_valid;

  // ============================================================
  // UART Terminal Model
  // ============================================================

  logic [7:0] term_byte;
  logic       term_valid;
  logic       term_frame_error;

  logic       terminal_seen;

  // ============================================================
  // Virtual Fan Model
  // ============================================================

  logic        fan_rst;
  logic [31:0] fan_duty_permille;
  logic        fan_sample_valid;

  // ============================================================
  // Test Variables
  // ============================================================

  integer timeout;

  // ============================================================
  // DUT
  // ============================================================

  riscv_fan_soc #(
   .IMEM_WORDS(1024),
   .DMEM_WORDS(1024),
   .CFG_WORDS (256),

    .PWM_DEFAULT_PERIOD(32'd100),

    // Fast value for simulation.
    .UART_DEFAULT_BAUD_DIV(UART_DIV),

    // Fast SPI for simulation.
    .SPI_DEFAULT_CLK_DIV(32'd2)
  ) dut (
    .clk_i                  (clk),
    .rst_i                  (rst),

    .pwm_o                  (pwm),

    .uart_tx_o              (uart_tx),
    .uart_rx_i              (uart_rx),

    .spi_sclk_o             (sclk),
    .spi_mosi_o             (mosi),
    .spi_miso_i             (miso),
    .spi_cs_n_o             (csn),

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
  // CPU sends:
  //
  //      0xA5
  //
  // Slave returns:
  //
  //      0x3C
  //
  // ============================================================

  spi_slave_model #(
    .RESPONSE(8'h3C)
  ) spi_slave (
    .rst_i      (rst),

    .cs_n_i     (csn),
    .sclk_i     (sclk),
    .mosi_i     (mosi),

    .miso_o     (miso),

    .last_rx_o  (spi_slave_rx),
    .rx_valid_o (spi_slave_valid)
  );

  // ============================================================
  // UART Terminal Model
  // ============================================================
  //
  // Monitors the SoC UART TX line.
  //
  // Expected transmitted byte:
  //
  //      0x48 = ASCII 'H'
  //
  // ============================================================

  uart_terminal_model #(
    .BAUD_DIV(UART_DIV)
  ) terminal (
    .clk_i              (clk),
    .rst_i              (rst),

    .serial_i           (uart_tx),

    .last_byte_o        (term_byte),
    .byte_valid_o       (term_valid),
    .framing_error_o    (term_frame_error)
  );

  // ============================================================
  // Virtual Fan Model
  // ============================================================
  //
  // PWM period:
  //
  //      100 clocks
  //
  // PWM high:
  //
  //      30 clocks
  //
  // Therefore expected:
  //
  //      300 permille
  //      = 30%
  //
  // ============================================================

  virtual_fan_model #(
    .WINDOW_CYCLES(100)
  ) fan_model (
    .clk_i             (clk),
    .rst_i             (fan_rst),

    .pwm_i             (pwm),

    .duty_permille_o   (fan_duty_permille),
    .sample_valid_o    (fan_sample_valid)
  );

  // ============================================================
  // UART RX Stimulus Task
  // ============================================================
  //
  // Sends one complete 8N1 UART byte INTO the SoC.
  //
  // ============================================================

  task automatic uart_send_byte (
    input [7:0] data
  );

    integer k;

    begin

      // --------------------------------------------------------
      // Start bit
      // --------------------------------------------------------

      @(negedge clk);

      uart_rx = 1'b0;

      repeat (UART_DIV)
        @(posedge clk);

      // --------------------------------------------------------
      // 8 Data Bits
      // UART is LSB-first.
      // --------------------------------------------------------

      for (k = 0; k < 8; k = k + 1) begin

        @(negedge clk);

        uart_rx = data[k];

        repeat (UART_DIV)
          @(posedge clk);

      end

      // --------------------------------------------------------
      // Stop bit
      // --------------------------------------------------------

      @(negedge clk);

      uart_rx = 1'b1;

      repeat (UART_DIV * 2)
        @(posedge clk);

    end

  endtask

  // ============================================================
  // Sticky UART Terminal Detection
  // ============================================================

  always_ff @(posedge clk) begin

    if (rst) begin

      terminal_seen <= 1'b0;

    end
    else if (
      term_valid &&
      term_byte == 8'h48
    ) begin

      terminal_seen <= 1'b1;

    end

  end

  // ============================================================
  // MAIN TEST
  // ============================================================

  initial begin

    /*
     * Hold the virtual fan model in reset until PWM has been
     * completely configured by firmware.
     */
    fan_rst = 1'b1;

    /*
     * Allow RAM-model initial blocks to execute first.
     */
    #1;

    // ============================================================
// PRELOAD RV32I FIRMWARE INTO INSTRUCTION SRAM
// ============================================================
//
// ASIC SRAM does not power-up from a Quartus MIF file.
// For RTL verification the testbench explicitly loads the
// program before reset is released.
//
// ============================================================

$readmemh(
  "firmware/soc_demo.hex",
  dut.u_imem.u_imem_ip.mem
);

$display(
  "IMEM firmware loaded. First instruction = %08x",
  dut.u_imem.u_imem_ip.mem[0]
);

    // ==========================================================
    // TESTBENCH PRELOADS CONFIGURATION SRAM
    // ==========================================================
    //
    // This directly satisfies the project requirement that the
    // testbench provides configuration values before normal CPU
    // operation.
    //
    // Configuration SRAM:
    //
    // Address 0x2000_0000
    //     Word 0 = PWM Period = 100
    //
    // Address 0x2000_0004
    //     Word 1 = PWM Duty = 30
    //
    // Address 0x2000_0008
    //     Word 2 = UART Data = 0x48 ('H')
    //
    // Address 0x2000_000C
    //     Word 3 = SPI Data = 0xA5
    //
    // ==========================================================

    dut.u_cfg.u_cfg_ip.mem[0] =
      32'h0000_0064;

    dut.u_cfg.u_cfg_ip.mem[1] =
      32'h0000_001E;

    dut.u_cfg.u_cfg_ip.mem[2] =
      32'h0000_0048;

    dut.u_cfg.u_cfg_ip.mem[3] =
      32'h0000_00A5;

    // ==========================================================
    // Verify configuration preload
    // ==========================================================

    if (
      dut.u_cfg.u_cfg_ip.mem[0] !==
      32'd100
    )
      $fatal(
        1,
        "CFG word 0 preload failed"
      );

    if (
      dut.u_cfg.u_cfg_ip.mem[1] !==
      32'd30
    )
      $fatal(
        1,
        "CFG word 1 preload failed"
      );

    if (
      dut.u_cfg.u_cfg_ip.mem[2] !==
      32'h48
    )
      $fatal(
        1,
        "CFG word 2 preload failed"
      );

    if (
      dut.u_cfg.u_cfg_ip.mem[3] !==
      32'hA5
    )
      $fatal(
        1,
        "CFG word 3 preload failed"
      );

    // ==========================================================
    // RESET
    // ==========================================================

    repeat (5)
      @(posedge clk);

    @(negedge clk);

    rst = 1'b0;

    // ==========================================================
    // STEP 1:
    // Wait for CPU → UART TX transaction
    // ==========================================================
    //
    // Firmware reads:
    //
    //      CFG[2] = 0x48
    //
    // and writes it to:
    //
    //      UART TXDATA
    //
    // External terminal should receive 'H'.
    //
    // ==========================================================

    timeout = 0;

    while (
      !terminal_seen &&
      timeout < 1500
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    if (timeout >= 1500) begin

      $fatal(
        1,
        "SoC UART TX timeout pc=%08x state=%0d",
        pc,
        state
      );

    end

    if (term_frame_error) begin

      $fatal(
        1,
        "UART terminal framing error"
      );

    end

    if (term_byte !== 8'h48) begin

      $fatal(
        1,
        "UART terminal expected 0x48 got 0x%02x",
        term_byte
      );

    end

    // ==========================================================
    // STEP 2:
    // Send UART RX byte into the SoC
    // ==========================================================
    //
    // Send:
    //
    //      0x5A
    //
    // Firmware will later read RXDATA and save it into:
    //
    //      DMEM[1]
    //
    // ==========================================================

    repeat (8)
      @(posedge clk);

    uart_send_byte(8'h5A);

    // ==========================================================
    // STEP 3:
    // Wait for firmware results in DMEM
    // ==========================================================
    //
    // Expected:
    //
    // DMEM[0] = SPI RX = 0x3C
    //
    // DMEM[1] = UART RX = 0x5A
    //
    // NEW RAM hierarchy:
    //
    // dut.u_dmem.u_dmem_ip.mem[]
    //
    // ==========================================================

    timeout = 0;

    while (
      (
        dut.u_dmem.u_dmem_ip.mem[0] !==
          32'h0000_003C
        ||
        dut.u_dmem.u_dmem_ip.mem[1] !==
          32'h0000_005A
      )
      &&
      timeout < 5000
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    if (timeout >= 5000) begin

      $fatal(
        1,
        "SoC result timeout d0=%08x d1=%08x pc=%08x state=%0d",
        dut.u_dmem.u_dmem_ip.mem[0],
        dut.u_dmem.u_dmem_ip.mem[1],
        pc,
        state
      );

    end

    // ==========================================================
    // STEP 4:
    // CPU must still be running normally
    // ==========================================================

    if (halted || trap) begin

      $fatal(
        1,
        "Unexpected core trap cause=%0d pc=%08x state=%0d",
        cause,
        pc,
        state
      );

    end

    // ==========================================================
    // STEP 5:
    // Verify SPI
    // ==========================================================
    //
    // CPU:
    //
    //      TX = 0xA5
    //
    // External slave:
    //
    //      RX = 0xA5
    //      TX = 0x3C
    //
    // CPU:
    //
    //      RX = 0x3C
    //
    // ==========================================================

    if (!spi_slave_valid) begin

      $fatal(
        1,
        "SPI slave did not receive complete transfer"
      );

    end

    if (spi_slave_rx !== 8'hA5) begin

      $fatal(
        1,
        "SPI slave expected 0xA5 got 0x%02x",
        spi_slave_rx
      );

    end

    if (dut.u_spi.tx_data_q !== 8'hA5) begin

      $fatal(
        1,
        "SPI TX register expected 0xA5 got 0x%02x",
        dut.u_spi.tx_data_q
      );

    end

    if (dut.u_spi.rx_data_q !== 8'h3C) begin

      $fatal(
        1,
        "SPI RX register expected 0x3C got 0x%02x",
        dut.u_spi.rx_data_q
      );

    end

    // ==========================================================
    // STEP 6:
    // Verify UART RX result
    // ==========================================================

    if (
      dut.u_dmem.u_dmem_ip.mem[1] !==
      32'h0000_005A
    ) begin

      $fatal(
        1,
        "UART RX result expected 0x5A got %08x",
        dut.u_dmem.u_dmem_ip.mem[1]
      );

    end

    // ==========================================================
    // STEP 7:
    // Verify PWM Registers
    // ==========================================================

    if (
      dut.u_pwm.enable_q !==
      1'b1
    ) begin

      $fatal(
        1,
        "PWM was not enabled"
      );

    end

    if (
      dut.u_pwm.period_q !==
      32'd100
    ) begin

      $fatal(
        1,
        "PWM period expected 100 got %0d",
        dut.u_pwm.period_q
      );

    end

    if (
      dut.u_pwm.duty_q !==
      32'd30
    ) begin

      $fatal(
        1,
        "PWM duty expected 30 got %0d",
        dut.u_pwm.duty_q
      );

    end

    // ==========================================================
    // STEP 8:
    // Virtual Fan Verification
    // ==========================================================
    //
    // Start fan measurement only after the CPU has fully
    // configured PWM.
    //
    // ==========================================================

    @(negedge clk);

    fan_rst = 1'b0;

    timeout = 0;

    while (
      !fan_sample_valid &&
      timeout < 200
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    if (timeout >= 200) begin

      $fatal(
        1,
        "Virtual fan measurement timeout"
      );

    end

    /*
     * 30% PWM:
     *
     *      30 / 100 = 0.30
     *
     * Virtual fan expresses duty in permille:
     *
     *      0.30 * 1000 = 300
     */
    if (
      fan_duty_permille !==
      32'd300
    ) begin

      $fatal(
        1,
        "Virtual fan expected 300 permille (30%%), got %0d",
        fan_duty_permille
      );

    end

    // ==========================================================
    // STEP 9:
    // Final no-trap check
    // ==========================================================

    if (halted || trap) begin

      $fatal(
        1,
        "Core trapped during final system verification cause=%0d",
        cause
      );

    end

    // ==========================================================
    // PASS
    // ==========================================================

    $display("");
    $display("==================================================");
    $display("[PASS] tb_soc");
    $display("==================================================");

    $display(
      "CFG PWM period   : %0d",
      dut.u_cfg.u_cfg_ip.mem[0]
    );

    $display(
      "CFG PWM duty     : %0d",
      dut.u_cfg.u_cfg_ip.mem[1]
    );

    $display(
      "PWM output       : 100/30 = 30%%"
    );

    $display(
      "Virtual fan duty : %0d permille",
      fan_duty_permille
    );

    $display(
      "UART TX          : 0x%02x ('H')",
      term_byte
    );

    $display(
      "UART RX          : 0x%02x",
      dut.u_dmem.u_dmem_ip.mem[1][7:0]
    );

    $display(
      "SPI TX           : 0x%02x",
      spi_slave_rx
    );

    $display(
      "SPI RX           : 0x%02x",
      dut.u_dmem.u_dmem_ip.mem[0][7:0]
    );

    $display(
      "CPU PC           : 0x%08x",
      pc
    );

    $display(
      "CPU State        : %0d",
      state
    );

    $display("==================================================");

    $finish;

  end

endmodule