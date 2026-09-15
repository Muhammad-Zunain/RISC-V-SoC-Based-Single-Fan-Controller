module riscv_fan_soc #(
  parameter integer IMEM_WORDS = 256,
  parameter integer DMEM_WORDS = 256,
  parameter integer CFG_WORDS  = 256,
  // Simulation-only initialization file parameters. In final ASIC macro mode,
  // SRAM/ROM contents are provided by the macro/boot architecture, not $readmemh.
  parameter IMEM_INIT_FILE = "",
  parameter CFG_INIT_FILE  = "",
  parameter logic [31:0] PWM_DEFAULT_PERIOD     = 32'd100,
  parameter logic [31:0] UART_DEFAULT_BAUD_DIV = 32'd434,
  parameter logic [31:0] SPI_DEFAULT_CLK_DIV   = 32'd25
) (
  input  logic        clk_i,
  input  logic        rst_i,
  output logic        pwm_o,
  output logic        uart_tx_o,
  input  logic        uart_rx_i,
  output logic        spi_sclk_o,
  output logic        spi_mosi_o,
  input  logic        spi_miso_i,
  output logic        spi_cs_n_o,
  output logic [31:0] debug_pc_o,
  output logic [31:0] debug_instr_o,
  output logic        debug_halted_o,
  output logic        debug_trap_o,
  output logic [31:0] debug_trap_cause_o,
  output logic [3:0]  debug_state_o
);
  import soc_pkg::*;

  // --------------------------------------------------------------------------
  // Core instruction interface
  // --------------------------------------------------------------------------
  logic        imem_req;
  logic [31:0] imem_addr;
  logic        imem_ready;
  logic [31:0] imem_rdata;
  logic        imem_fault;

  // --------------------------------------------------------------------------
  // Core data/MMIO interface
  // --------------------------------------------------------------------------
  logic        cpu_req, cpu_write;
  logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
  logic [3:0]  cpu_wstrb;
  logic        cpu_ready, cpu_fault;

  logic sel_dmem, sel_cfg, sel_pwm, sel_uart, sel_spi;
  logic decode_fault;

  logic        dmem_ready, dmem_fault;
  logic [31:0] dmem_rdata;
  logic        cfg_ready, cfg_fault;
  logic [31:0] cfg_rdata;
  logic [31:0] pwm_rdata, uart_rdata, spi_rdata;

  localparam logic [2:0] T_NONE  = 3'd0;
  localparam logic [2:0] T_DMEM  = 3'd1;
  localparam logic [2:0] T_CFG   = 3'd2;
  localparam logic [2:0] T_PWM   = 3'd3;
  localparam logic [2:0] T_UART  = 3'd4;
  localparam logic [2:0] T_SPI   = 3'd5;
  localparam logic [2:0] T_FAULT = 3'd6;

  logic [2:0]  target_q;
  logic        target_valid_q;
  logic [31:0] peripheral_rdata_q;

  rv32i_core #(.RESET_PC_P(RESET_PC)) u_core (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .imem_req_o(imem_req),
    .imem_addr_o(imem_addr),
    .imem_ready_i(imem_ready),
    .imem_rdata_i(imem_rdata),
    .imem_fault_i(imem_fault),
    .dmem_req_o(cpu_req),
    .dmem_write_o(cpu_write),
    .dmem_addr_o(cpu_addr),
    .dmem_wdata_o(cpu_wdata),
    .dmem_wstrb_o(cpu_wstrb),
    .dmem_ready_i(cpu_ready),
    .dmem_rdata_i(cpu_rdata),
    .dmem_fault_i(cpu_fault),
    .pc_o(debug_pc_o),
    .instr_o(debug_instr_o),
    .halted_o(debug_halted_o),
    .trap_o(debug_trap_o),
    .trap_cause_o(debug_trap_cause_o),
    .state_o(debug_state_o)
  );

  // Technology-independent synchronous instruction memory behind a one-cycle
  // request/ready wrapper.
  imem_ip_wrapper #(
    .WORDS(IMEM_WORDS),
    .INIT_FILE(IMEM_INIT_FILE)
  ) u_imem (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .req_i(imem_req),
    .addr_i(imem_addr),
    .ready_o(imem_ready),
    .rdata_o(imem_rdata),
    .fault_o(imem_fault)
  );

  mmio_decoder #(
    .DMEM_WORDS(DMEM_WORDS),
    .CFG_WORDS(CFG_WORDS)
  ) u_mmio_decoder (
    .valid_i(cpu_req),
    .addr_i(cpu_addr),
    .sel_dmem_o(sel_dmem),
    .sel_cfg_o(sel_cfg),
    .sel_pwm_o(sel_pwm),
    .sel_uart_o(sel_uart),
    .sel_spi_o(sel_spi),
    .fault_o(decode_fault)
  );

  dmem_ip_wrapper #(
    .WORDS(DMEM_WORDS),
    .BASE_ADDR(DMEM_BASE)
  ) u_dmem (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .req_i(cpu_req && sel_dmem),
    .write_i(cpu_write),
    .addr_i(cpu_addr),
    .wdata_i(cpu_wdata),
    .wstrb_i(cpu_wstrb),
    .ready_o(dmem_ready),
    .rdata_o(dmem_rdata),
    .fault_o(dmem_fault)
  );

  config_ip_wrapper #(
    .WORDS(CFG_WORDS),
    .BASE_ADDR(CFG_BASE),
    .INIT_FILE(CFG_INIT_FILE)
  ) u_cfg (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .req_i(cpu_req && sel_cfg),
    .write_i(cpu_write),
    .addr_i(cpu_addr),
    .wdata_i(cpu_wdata),
    .wstrb_i(cpu_wstrb),
    .ready_o(cfg_ready),
    .rdata_o(cfg_rdata),
    .fault_o(cfg_fault)
  );

  // Existing, already unit-tested peripherals remain unchanged. bus_valid_i is
  // asserted only in the core's one-cycle MEM_REQ state, preventing duplicate
  // writes while the core waits for the registered acknowledgement.
  pwm_peripheral #(
    .DEFAULT_PERIOD(PWM_DEFAULT_PERIOD),
    .DEFAULT_DUTY(32'd0)
  ) u_pwm (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .bus_valid_i(cpu_req && sel_pwm),
    .bus_we_i(cpu_write),
    .bus_addr_i(cpu_addr[11:0]),
    .bus_wdata_i(cpu_wdata),
    .bus_wstrb_i(cpu_wstrb),
    .bus_rdata_o(pwm_rdata),
    .pwm_o(pwm_o)
  );

  uart_peripheral #(.DEFAULT_BAUD_DIV(UART_DEFAULT_BAUD_DIV)) u_uart (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .bus_valid_i(cpu_req && sel_uart),
    .bus_we_i(cpu_write),
    .bus_addr_i(cpu_addr[11:0]),
    .bus_wdata_i(cpu_wdata),
    .bus_wstrb_i(cpu_wstrb),
    .bus_rdata_o(uart_rdata),
    .uart_tx_o(uart_tx_o),
    .uart_rx_i(uart_rx_i)
  );

  spi_peripheral #(.DEFAULT_CLK_DIV(SPI_DEFAULT_CLK_DIV)) u_spi (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .bus_valid_i(cpu_req && sel_spi),
    .bus_we_i(cpu_write),
    .bus_addr_i(cpu_addr[11:0]),
    .bus_wdata_i(cpu_wdata),
    .bus_wstrb_i(cpu_wstrb),
    .bus_rdata_o(spi_rdata),
    .spi_sclk_o(spi_sclk_o),
    .spi_mosi_o(spi_mosi_o),
    .spi_miso_i(spi_miso_i),
    .spi_cs_n_o(spi_cs_n_o)
  );

  // Latch the transaction destination and combinational peripheral read data at
  // the request edge. SRAM wrappers produce ready/data one cycle later; MMIO
  // registers and unmapped accesses are acknowledged one cycle later here.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      target_q           <= T_NONE;
      target_valid_q     <= 1'b0;
      peripheral_rdata_q <= 32'd0;
    end else begin
      // Capture a new CPU transaction.
      if (!target_valid_q && cpu_req) begin
        target_valid_q <= 1'b1;

        // Fault has highest priority.
        if (decode_fault)
          target_q <= T_FAULT;
        else if (sel_dmem)
          target_q <= T_DMEM;
        else if (sel_cfg)
          target_q <= T_CFG;
        else if (sel_pwm)
          target_q <= T_PWM;
        else if (sel_uart)
          target_q <= T_UART;
        else if (sel_spi)
          target_q <= T_SPI;
        else
          target_q <= T_FAULT;

        // MMIO read data is combinational, so capture it
        // when the request is accepted.
        if (sel_pwm)
          peripheral_rdata_q <= pwm_rdata;
        else if (sel_uart)
          peripheral_rdata_q <= uart_rdata;
        else if (sel_spi)
          peripheral_rdata_q <= spi_rdata;
        else
          peripheral_rdata_q <= 32'd0;
      end

      // Hold the transaction until the selected target replies.
      else if (target_valid_q && cpu_ready) begin
        target_valid_q <= 1'b0;
        target_q       <= T_NONE;
      end
    end
  end
  always_comb begin
    cpu_ready = 1'b0;
    cpu_fault = 1'b0;
    cpu_rdata = 32'd0;

    if (target_valid_q) begin
      case (target_q)
        T_DMEM: begin
          cpu_ready = dmem_ready;
          cpu_fault = dmem_fault;
          cpu_rdata = dmem_rdata;
        end
        T_CFG: begin
          cpu_ready = cfg_ready;
          cpu_fault = cfg_fault;
          cpu_rdata = cfg_rdata;
        end
        T_PWM, T_UART, T_SPI: begin
          cpu_ready = 1'b1;
          cpu_fault = 1'b0;
          cpu_rdata = peripheral_rdata_q;
        end
        T_FAULT: begin
          cpu_ready = 1'b1;
          cpu_fault = 1'b1;
          cpu_rdata = 32'd0;
        end
        default: begin
        end
      endcase
    end
  end
endmodule
