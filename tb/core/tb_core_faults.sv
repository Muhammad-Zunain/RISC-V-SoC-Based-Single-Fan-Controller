`timescale 1ns/1ps

module tb_core_faults;

  import soc_pkg::*;

  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk = 1'b0;
  logic rst = 1'b1;

  always #5 clk = ~clk;

  // ============================================================
  // Instruction memory interface
  // ============================================================

  logic        imem_req;
  logic [31:0] imem_addr;

  logic        imem_ready;
  logic [31:0] imem_rdata;
  logic        imem_fault;

  // ============================================================
  // Data memory interface
  // ============================================================

  logic        dmem_req;
  logic        dmem_write;

  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;

  logic        dmem_ready;
  logic [31:0] dmem_rdata;
  logic        dmem_fault;

  // ============================================================
  // Debug outputs
  // ============================================================

  logic [31:0] pc;
  logic [31:0] instr;

  logic        halted;
  logic        trap;
  logic [31:0] trap_cause;
  logic [3:0]  state;

  // ============================================================
  // Test memories
  // ============================================================

  logic [31:0] imem [0:15];
  logic [31:0] dmem [0:63];

  integer i;
  integer timeout;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  rv32i_core dut (
    .clk_i              (clk),
    .rst_i              (rst),

    // Instruction memory
    .imem_req_o         (imem_req),
    .imem_addr_o        (imem_addr),
    .imem_ready_i       (imem_ready),
    .imem_rdata_i       (imem_rdata),
    .imem_fault_i       (imem_fault),

    // Data memory
    .dmem_req_o         (dmem_req),
    .dmem_write_o       (dmem_write),
    .dmem_addr_o        (dmem_addr),
    .dmem_wdata_o       (dmem_wdata),
    .dmem_wstrb_o       (dmem_wstrb),

    .dmem_ready_i       (dmem_ready),
    .dmem_rdata_i       (dmem_rdata),
    .dmem_fault_i       (dmem_fault),

    // Debug
    .pc_o               (pc),
    .instr_o            (instr),
    .halted_o           (halted),
    .trap_o             (trap),
    .trap_cause_o       (trap_cause),
    .state_o            (state)
  );

  // ============================================================
  // Synchronous Instruction Memory Model
  // ============================================================
  //
  // Request:
  //
  //   Cycle N:
  //       imem_req = 1
  //
  // Response:
  //
  //   Cycle N+1:
  //       imem_ready = 1
  //       imem_rdata = instruction
  //
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      imem_ready <= 1'b0;
      imem_fault <= 1'b0;
      imem_rdata <= 32'h0000_0013;

    end
    else begin

      // One-cycle response
      imem_ready <= imem_req;

      if (imem_req) begin

        // Must be 4-byte aligned and inside 16-word IMEM
        if (
          (imem_addr[1:0] != 2'b00) ||
          (imem_addr[31:2] >= 16)
        ) begin

          imem_fault <= 1'b1;

          // Return NOP together with fault
          imem_rdata <= 32'h0000_0013;

        end
        else begin

          imem_fault <= 1'b0;

          imem_rdata <=
            imem[imem_addr[31:2]];

        end

      end
      else begin

        imem_fault <= 1'b0;

      end

    end

  end

  // ============================================================
  // Synchronous Data Memory / Fault Model
  // ============================================================
  //
  // For this fault testbench:
  //
  // Addresses below 0x100 are valid.
  //
  // Addresses >= 0x100 create a Data Access Fault.
  //
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      dmem_ready <= 1'b0;
      dmem_fault <= 1'b0;
      dmem_rdata <= 32'd0;

    end
    else begin

      // One-cycle response
      dmem_ready <= dmem_req;

      if (dmem_req) begin

        // ------------------------------------------------------
        // Invalid memory range
        // ------------------------------------------------------

        if (dmem_addr >= 32'h0000_0100) begin

          dmem_fault <= 1'b1;
          dmem_rdata <= 32'd0;

        end

        // ------------------------------------------------------
        // Valid memory range
        // ------------------------------------------------------

        else begin

          dmem_fault <= 1'b0;

          dmem_rdata <=
            dmem[dmem_addr[7:2]];

          // Store handling
          if (dmem_write) begin

            if (dmem_wstrb[0])
              dmem[dmem_addr[7:2]][7:0] <=
                dmem_wdata[7:0];

            if (dmem_wstrb[1])
              dmem[dmem_addr[7:2]][15:8] <=
                dmem_wdata[15:8];

            if (dmem_wstrb[2])
              dmem[dmem_addr[7:2]][23:16] <=
                dmem_wdata[23:16];

            if (dmem_wstrb[3])
              dmem[dmem_addr[7:2]][31:24] <=
                dmem_wdata[31:24];

          end

        end

      end
      else begin

        dmem_fault <= 1'b0;

      end

    end

  end

  // ============================================================
  // Clear Program
  // ============================================================

  task automatic clear_program;

    begin

      for (i = 0; i < 16; i = i + 1)
        imem[i] = 32'h0000_0013;

    end

  endtask

  // ============================================================
  // Run CPU and verify expected trap cause
  // ============================================================

  task automatic run_expect (
    input [31:0] expected_cause,
    input string test_name
  );

    begin

      // --------------------------------------------------------
      // Reset CPU
      // --------------------------------------------------------

      rst = 1'b1;

      repeat (3)
        @(posedge clk);

      @(negedge clk);

      rst = 1'b0;

      // --------------------------------------------------------
      // Wait for trap
      // --------------------------------------------------------

      timeout = 0;

      while (
        !halted &&
        timeout < 100
      ) begin

        @(posedge clk);

        timeout =
          timeout + 1;

      end

      // --------------------------------------------------------
      // Check timeout
      // --------------------------------------------------------

      if (timeout >= 100) begin

        $fatal(
          1,
          "%s TIMEOUT: pc=%08x state=%0d",
          test_name,
          pc,
          state
        );

      end

      // --------------------------------------------------------
      // Check trap
      // --------------------------------------------------------

      if (!trap) begin

        $fatal(
          1,
          "%s: CPU halted without trap",
          test_name
        );

      end

      // --------------------------------------------------------
      // Check cause
      // --------------------------------------------------------

      if (trap_cause !== expected_cause) begin

        $fatal(
          1,
          "%s: expected cause=%0d got=%0d pc=%08x state=%0d",
          test_name,
          expected_cause,
          trap_cause,
          pc,
          state
        );

      end

      $display(
        "[PASS] %-28s cause=%0d",
        test_name,
        trap_cause
      );

    end

  endtask

  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    // ----------------------------------------------------------
    // Initial values
    // ----------------------------------------------------------

    imem_ready = 1'b0;
    imem_fault = 1'b0;
    imem_rdata = 32'h0000_0013;

    dmem_ready = 1'b0;
    dmem_fault = 1'b0;
    dmem_rdata = 32'd0;

    for (i = 0; i < 16; i = i + 1)
      imem[i] = 32'h0000_0013;

    for (i = 0; i < 64; i = i + 1)
      dmem[i] = 32'd0;

    // ==========================================================
    // TEST 1
    // Illegal Instruction
    //
    // Expected cause = 2
    // ==========================================================

    clear_program();

    imem[0] =
      32'hFFFF_FFFF;

    run_expect(
      CAUSE_ILLEGAL_INSTR,
      "Illegal Instruction"
    );

    // ==========================================================
    // TEST 2
    // Misaligned Load
    //
    // LW x1,1(x0)
    //
    // Word load requires address multiple of 4.
    //
    // Expected cause = 4
    // ==========================================================

    clear_program();

    imem[0] =
      enc_i(
        1,
        0,
        3'b010,
        1,
        7'b0000011
      );

    run_expect(
      CAUSE_LOAD_MISALIGNED,
      "Misaligned LW"
    );

    // ==========================================================
    // TEST 3
    // Misaligned Store
    //
    // SW x0,2(x0)
    //
    // Expected cause = 6
    // ==========================================================

    clear_program();

    imem[0] =
      enc_s(
        2,
        0,
        0,
        3'b010
      );

    run_expect(
      CAUSE_STORE_MISALIGNED,
      "Misaligned SW"
    );

    // ==========================================================
    // TEST 4
    // Misaligned JALR target
    //
    // x1 = 2
    //
    // JALR target:
    //
    //     (2 + 0) & ~1
    //       = 2
    //
    // RV32I without compressed instructions requires PC[1:0]=00.
    //
    // Expected cause = 0
    // ==========================================================

    clear_program();

    // ADDI x1,x0,2
    imem[0] =
      enc_i(
        2,
        0,
        3'b000,
        1,
        7'b0010011
      );

    // JALR x0,0(x1)
    imem[1] =
      enc_i(
        0,
        1,
        3'b000,
        0,
        7'b1100111
      );

    run_expect(
      CAUSE_INSTR_MISALIGNED,
      "Misaligned JALR"
    );

    // ==========================================================
    // TEST 5
    // Instruction Access Fault
    //
    // JAL x0,+64
    //
    // IMEM contains only:
    //
    //     16 words = 64 bytes
    //
    // Address 0x40 is therefore outside memory.
    //
    // Expected cause = 1
    // ==========================================================

    clear_program();

    imem[0] =
      enc_j(
        64,
        0
      );

    run_expect(
      CAUSE_INSTR_ACCESS,
      "Instruction Access Fault"
    );

    // ==========================================================
    // TEST 6
    // Load Access Fault
    //
    // LW x1,0x100(x0)
    //
    // Testbench marks addresses >= 0x100 invalid.
    //
    // Expected cause = 5
    // ==========================================================

    clear_program();

    imem[0] =
      enc_i(
        12'h100,
        0,
        3'b010,
        1,
        7'b0000011
      );

    run_expect(
      CAUSE_LOAD_ACCESS,
      "Load Access Fault"
    );

    // ==========================================================
    // TEST 7
    // Store Access Fault
    //
    // SW x0,0x100(x0)
    //
    // Expected cause = 7
    // ==========================================================

    clear_program();

    imem[0] =
      enc_s(
        12'h100,
        0,
        0,
        3'b010
      );

    run_expect(
      CAUSE_STORE_ACCESS,
      "Store Access Fault"
    );

    // ==========================================================
    // TEST 8
    // ECALL
    //
    // Expected cause = 11
    // ==========================================================

    clear_program();

    imem[0] =
      32'h0000_0073;

    run_expect(
      CAUSE_ECALL,
      "ECALL"
    );

    // ==========================================================
    // TEST 9
    // EBREAK
    //
    // Expected cause = 3
    // ==========================================================

    clear_program();

    imem[0] =
      32'h0010_0073;

    run_expect(
      CAUSE_BREAKPOINT,
      "EBREAK"
    );

    // ==========================================================
    // All Fault Tests Passed
    // ==========================================================

    $display("");
    $display("========================================");
    $display("[PASS] tb_core_faults");
    $display("All RV32I exception tests passed.");
    $display("========================================");

    $finish;

  end

endmodule