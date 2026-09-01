`timescale 1ns/1ps

module tb_rv32i_core;

  logic clk = 0;
  logic rst = 1;

  // ------------------------------------------------------------
  // Instruction memory interface
  // ------------------------------------------------------------
  logic        ireq;
  logic        iready;
  logic        ifault;
  logic [31:0] ia;
  logic [31:0] ir;

  // ------------------------------------------------------------
  // Data memory interface
  // ------------------------------------------------------------
  logic        dreq;
  logic        dw;
  logic        dready;
  logic        dfault;

  logic [31:0] da;
  logic [31:0] dwd;
  logic [31:0] drd;
  logic [3:0]  dstrb;

  // ------------------------------------------------------------
  // Debug
  // ------------------------------------------------------------
  logic [31:0] pc;
  logic [31:0] ins;
  logic [31:0] cause;

  logic        halted;
  logic        trap;
  logic [3:0]  state;

  // ------------------------------------------------------------
  // Simple synchronous memories used only by this core TB
  // ------------------------------------------------------------
  logic [31:0] imem [0:127];
  logic [31:0] dmem [0:31];

  integer i;
  integer timeout;

  `include "tb/common/rv32i_encode.svh"

  // 100 MHz test clock
  always #5 clk = ~clk;

  // ============================================================
  // DUT
  // ============================================================

  rv32i_core dut (
    .clk_i          (clk),
    .rst_i          (rst),

    .imem_req_o     (ireq),
    .imem_addr_o    (ia),
    .imem_ready_i   (iready),
    .imem_rdata_i   (ir),
    .imem_fault_i   (ifault),

    .dmem_req_o     (dreq),
    .dmem_write_o   (dw),
    .dmem_addr_o    (da),
    .dmem_wdata_o   (dwd),
    .dmem_wstrb_o   (dstrb),
    .dmem_ready_i   (dready),
    .dmem_rdata_i   (drd),
    .dmem_fault_i   (dfault),

    .pc_o           (pc),
    .instr_o        (ins),
    .halted_o       (halted),
    .trap_o         (trap),
    .trap_cause_o   (cause),
    .state_o        (state)
  );

  // ============================================================
  // One-cycle synchronous Instruction Memory model
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      iready <= 1'b0;
      ifault <= 1'b0;
      ir     <= 32'h0000_0013;   // NOP

    end
    else begin

      // Request from previous cycle is acknowledged.
      iready <= ireq;

      if (ireq) begin

        ifault <=
          (ia[1:0] != 2'b00) ||
          (ia[31:2] >= 128);

        if (
          (ia[1:0] == 2'b00) &&
          (ia[31:2] < 128)
        )
          ir <= imem[ia[31:2]];

        else
          ir <= 32'h0000_0013;

      end

    end

  end

  // ============================================================
  // One-cycle synchronous Data Memory model
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      dready <= 1'b0;
      dfault <= 1'b0;
      drd    <= 32'd0;

    end
    else begin

      dready <= dreq;

      if (dreq) begin

        dfault <= (da[31:2] >= 32);

        if (da[31:2] < 32) begin

          // Read complete 32-bit word.
          drd <= dmem[da[31:2]];

          // Perform write according to byte strobes.
          if (dw) begin

            if (dstrb[0])
              dmem[da[31:2]][7:0] <=
                dwd[7:0];

            if (dstrb[1])
              dmem[da[31:2]][15:8] <=
                dwd[15:8];

            if (dstrb[2])
              dmem[da[31:2]][23:16] <=
                dwd[23:16];

            if (dstrb[3])
              dmem[da[31:2]][31:24] <=
                dwd[31:24];

          end

        end
        else begin

          drd <= 32'd0;

        end

      end

    end

  end

  // ============================================================
  // Test
  // ============================================================

  initial begin

    // Initial interface values
    iready = 1'b0;
    ifault = 1'b0;
    ir     = 32'h0000_0013;

    dready = 1'b0;
    dfault = 1'b0;
    drd    = 32'd0;

    // ----------------------------------------------------------
    // Initialize memories
    // ----------------------------------------------------------

    for (i = 0; i < 128; i = i + 1)
      imem[i] = 32'h0000_0013;

    for (i = 0; i < 32; i = i + 1)
      dmem[i] = 32'd0;

    // ==========================================================
    // Test Program
    // ==========================================================

    // x1 = 5
    imem[0] =
      enc_i(
        5,
        0,
        3'b000,
        1,
        7'b0010011
      );

    // x2 = 7
    imem[1] =
      enc_i(
        7,
        0,
        3'b000,
        2,
        7'b0010011
      );

    // ----------------------------------------------------------
    // R-TYPE
    // ADD x3,x1,x2
    // expected x3 = 12
    //
    // State flow:
    // FETCH_REQ
    // FETCH_WAIT
    // DECODE
    // EXECUTE
    // ALU_WB
    // ----------------------------------------------------------

    imem[2] =
      enc_r(
        7'b0000000,
        2,
        1,
        3'b000,
        3,
        7'b0110011
      );

    // ----------------------------------------------------------
    // STORE
    // SW x3,0(x0)
    //
    // Expected:
    // dmem[0] = 12
    //
    // State flow:
    // FETCH_REQ
    // FETCH_WAIT
    // DECODE
    // EXECUTE
    // MEM_REQ
    // MEM_WAIT
    // ----------------------------------------------------------

    imem[3] =
      enc_s(
        0,
        3,
        0,
        3'b010
      );

    // ----------------------------------------------------------
    // LOAD
    // LW x4,0(x0)
    //
    // Expected:
    // x4 = 12
    //
    // State flow:
    // FETCH_REQ
    // FETCH_WAIT
    // DECODE
    // EXECUTE
    // MEM_REQ
    // MEM_WAIT
    // LOAD_WB
    // ----------------------------------------------------------

    imem[4] =
      enc_i(
        0,
        0,
        3'b010,
        4,
        7'b0000011
      );

    // ----------------------------------------------------------
    // BRANCH
    // BEQ x3,x4,+8
    //
    // x3 = 12
    // x4 = 12
    //
    // Branch must be TAKEN.
    //
    // State flow:
    // FETCH_REQ
    // FETCH_WAIT
    // DECODE
    // EXECUTE
    // ----------------------------------------------------------

    imem[5] =
      enc_b(
        8,
        4,
        3,
        3'b000
      );

    // This instruction must be skipped.
    imem[6] =
      enc_i(
        99,
        0,
        3'b000,
        5,
        7'b0010011
      );

    // Branch target
    // x5 = 1
    imem[7] =
      enc_i(
        1,
        0,
        3'b000,
        5,
        7'b0010011
      );

    // ----------------------------------------------------------
    // EBREAK
    // End simulation through breakpoint trap.
    // ----------------------------------------------------------

    imem[8] = 32'h0010_0073;

    // ==========================================================
    // Reset
    // ==========================================================

    repeat (4)
      @(posedge clk);

    @(negedge clk);
    rst = 1'b0;

    // ==========================================================
    // Wait for CPU to reach EBREAK
    // ==========================================================

    timeout = 0;

    while (
      !halted &&
      timeout < 500
    ) begin

      @(posedge clk);

      timeout =
        timeout + 1;

    end

    // ==========================================================
    // Self-checks
    // ==========================================================

    if (timeout >= 500)
      $fatal(
        1,
        "Core timeout pc=%08x state=%0d",
        pc,
        state
      );

    if (
      !trap ||
      cause != 32'd3
    )
      $fatal(
        1,
        "Expected EBREAK cause=3, got %0d",
        cause
      );

    if (
      dut.u_regfile.regs[1] !==
      32'd5
    )
      $fatal(
        1,
        "ADDI x1 failed"
      );

    if (
      dut.u_regfile.regs[2] !==
      32'd7
    )
      $fatal(
        1,
        "ADDI x2 failed"
      );

    if (
      dut.u_regfile.regs[3] !==
      32'd12
    )
      $fatal(
        1,
        "R-Type ADD failed"
      );

    if (
      dmem[0] !==
      32'd12
    )
      $fatal(
        1,
        "STORE failed dmem[0]=%08x",
        dmem[0]
      );

    if (
      dut.u_regfile.regs[4] !==
      32'd12
    )
      $fatal(
        1,
        "LOAD failed"
      );

    if (
      dut.u_regfile.regs[5] !==
      32'd1
    )
      $fatal(
        1,
        "BRANCH failed"
      );

    if (
      dut.u_regfile.regs[0] !==
      32'd0
    )
      $fatal(
        1,
        "x0 corrupted"
      );

    $display(
      "[PASS] tb_rv32i_core"
    );

    $finish;

  end

endmodule