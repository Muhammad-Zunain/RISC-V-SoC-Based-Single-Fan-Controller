`timescale 1ns/1ps

module tb_core_cycle_count;

  // ============================================================
  // Current Multicycle FSM State Values
  // ============================================================

  localparam logic [3:0] ST_FETCH_REQ  = 4'd0;
  localparam logic [3:0] ST_FETCH_WAIT = 4'd1;
  localparam logic [3:0] ST_DECODE     = 4'd2;
  localparam logic [3:0] ST_EXECUTE    = 4'd3;
  localparam logic [3:0] ST_ALU_WB     = 4'd4;
  localparam logic [3:0] ST_MEM_REQ    = 4'd5;
  localparam logic [3:0] ST_MEM_WAIT   = 4'd6;
  localparam logic [3:0] ST_LOAD_WB    = 4'd7;
  localparam logic [3:0] ST_TRAP       = 4'd8;

  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk = 1'b0;
  logic rst = 1'b1;

  always #5 clk = ~clk;

  // ============================================================
  // Instruction Memory Interface
  // ============================================================

  logic        imem_req;
  logic [31:0] imem_addr;
  logic        imem_ready;
  logic [31:0] imem_rdata;
  logic        imem_fault;

  // ============================================================
  // Data Memory Interface
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
  // Debug
  // ============================================================

  logic [31:0] pc;
  logic [31:0] instr;

  logic        halted;
  logic        trap;
  logic [31:0] trap_cause;
  logic [3:0]  state;

  // ============================================================
  // Simple Test Memories
  // ============================================================

  logic [31:0] imem [0:63];
  logic [31:0] dmem [0:31];

  integer i;

  integer total_cycles;
  integer instruction_count;

  `include "tb/common/rv32i_encode.svh"

  // ============================================================
  // DUT
  // ============================================================

  rv32i_core dut (
    .clk_i            (clk),
    .rst_i            (rst),

    // Instruction interface
    .imem_req_o       (imem_req),
    .imem_addr_o      (imem_addr),
    .imem_ready_i     (imem_ready),
    .imem_rdata_i     (imem_rdata),
    .imem_fault_i     (imem_fault),

    // Data interface
    .dmem_req_o       (dmem_req),
    .dmem_write_o     (dmem_write),
    .dmem_addr_o      (dmem_addr),
    .dmem_wdata_o     (dmem_wdata),
    .dmem_wstrb_o     (dmem_wstrb),

    .dmem_ready_i     (dmem_ready),
    .dmem_rdata_i     (dmem_rdata),
    .dmem_fault_i     (dmem_fault),

    // Debug
    .pc_o             (pc),
    .instr_o          (instr),
    .halted_o         (halted),
    .trap_o           (trap),
    .trap_cause_o     (trap_cause),
    .state_o          (state)
  );

  // ============================================================
  // One-Cycle Synchronous Instruction Memory
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      imem_ready <= 1'b0;
      imem_fault <= 1'b0;
      imem_rdata <= 32'h0000_0013;

    end
    else begin

      // Request is acknowledged one cycle later.
      imem_ready <= imem_req;

      if (imem_req) begin

        if (
          (imem_addr[1:0] != 2'b00) ||
          (imem_addr[31:2] >= 64)
        ) begin

          imem_fault <= 1'b1;
          imem_rdata <= 32'h0000_0013;

        end
        else begin

          imem_fault <= 1'b0;
          imem_rdata <= imem[imem_addr[31:2]];

        end

      end
      else begin

        imem_fault <= 1'b0;

      end

    end

  end

  // ============================================================
  // One-Cycle Synchronous Data Memory
  // ============================================================

  always @(posedge clk) begin

    if (rst) begin

      dmem_ready <= 1'b0;
      dmem_fault <= 1'b0;
      dmem_rdata <= 32'd0;

    end
    else begin

      dmem_ready <= dmem_req;

      if (dmem_req) begin

        if (dmem_addr[31:2] >= 32) begin

          dmem_fault <= 1'b1;
          dmem_rdata <= 32'd0;

        end
        else begin

          dmem_fault <= 1'b0;

          // Read
          dmem_rdata <=
            dmem[dmem_addr[31:2]];

          // Write
          if (dmem_write) begin

            if (dmem_wstrb[0])
              dmem[dmem_addr[31:2]][7:0]
                <= dmem_wdata[7:0];

            if (dmem_wstrb[1])
              dmem[dmem_addr[31:2]][15:8]
                <= dmem_wdata[15:8];

            if (dmem_wstrb[2])
              dmem[dmem_addr[31:2]][23:16]
                <= dmem_wdata[23:16];

            if (dmem_wstrb[3])
              dmem[dmem_addr[31:2]][31:24]
                <= dmem_wdata[31:24];

          end

        end

      end
      else begin

        dmem_fault <= 1'b0;

      end

    end

  end

  // ============================================================
  // Cycle Counter Task
  // ============================================================

  task automatic check_instruction (
    input integer number,
    input [31:0] expected_pc,
    input integer expected_cycles,
    input string instruction_name
  );

    integer cycles;

    begin

      // --------------------------------------------------------
      // Wait until this instruction reaches FETCH_REQ
      // --------------------------------------------------------

      while (
        !(
          state == ST_FETCH_REQ &&
          pc    == expected_pc
        )
      ) begin

        @(negedge clk);

        if (trap || halted) begin

          $fatal(
            1,
            "%s: CPU trapped before PC=%08x",
            instruction_name,
            expected_pc
          );

        end

      end

      cycles = 0;

      instruction_count =
        instruction_count + 1;

      $display("");
      $display(
        "=============================================================="
      );

      $display(
        "INSTRUCTION #%0d : %s",
        number,
        instruction_name
      );

      $display(
        "START PC         : 0x%08x",
        pc
      );

      $display(
        "=============================================================="
      );

      $display(
        " Inst#   Cycle   TotalClk   PC          State"
      );

      $display(
        " -------------------------------------------------------------"
      );

      // --------------------------------------------------------
      // Count until CPU returns to FETCH_REQ for next instruction
      // --------------------------------------------------------

      forever begin

        $display(
          "   %0d       %0d       %0d      0x%08x    %0d",
          number,
          cycles + 1,
          total_cycles + 1,
          pc,
          state
        );

        @(posedge clk);

        cycles =
          cycles + 1;

        total_cycles =
          total_cycles + 1;

        /*
         * Let nonblocking assignments update state_q and pc_q.
         */
        #1;

        /*
         * Once state returns to FETCH_REQ, the current
         * instruction has completed.
         */
        if (state == ST_FETCH_REQ)
          break;

        if (cycles > 20) begin

          $fatal(
            1,
            "%s exceeded expected maximum cycles",
            instruction_name
          );

        end

      end

      // --------------------------------------------------------
      // Cycle-count check
      // --------------------------------------------------------

      if (cycles != expected_cycles) begin

        $fatal(
          1,
          "%s cycle mismatch: expected=%0d actual=%0d",
          instruction_name,
          expected_cycles,
          cycles
        );

      end

      // --------------------------------------------------------
      // Instruction result
      // --------------------------------------------------------

      $display(
        " -------------------------------------------------------------"
      );

      $display(
        "[PASS] Instruction #%0d %-10s PC=0x%08x Cycles=%0d Total=%0d NextPC=0x%08x",
        number,
        instruction_name,
        expected_pc,
        cycles,
        total_cycles,
        pc
      );

    end

  endtask

  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    // ----------------------------------------------------------
    // Initial signals
    // ----------------------------------------------------------

    imem_ready = 1'b0;
    imem_fault = 1'b0;
    imem_rdata = 32'h0000_0013;

    dmem_ready = 1'b0;
    dmem_fault = 1'b0;
    dmem_rdata = 32'd0;

    total_cycles      = 0;
    instruction_count = 0;

    // ----------------------------------------------------------
    // Clear memories
    // ----------------------------------------------------------

    for (i = 0; i < 64; i = i + 1)
      imem[i] = 32'h0000_0013;

    for (i = 0; i < 32; i = i + 1)
      dmem[i] = 32'd0;

    // ==========================================================
    // Initial Data Memory
    // ==========================================================

    /*
     * First LOAD:
     *
     * LW x7,0(x0)
     *
     * Expected x7 = 0x11223344
     */
    dmem[0] =
      32'h1122_3344;

    /*
     * dmem[1] will later be written by:
     *
     * SW x3,4(x0)
     */

    dmem[1] =
      32'd0;

    // ==========================================================
    // EXACTLY 8 EXECUTED INSTRUCTIONS
    // ==========================================================

    // ----------------------------------------------------------
    // #1
    // PC = 0x00000000
    //
    // ADD x3,x1,x2
    //
    // x1 = 5
    // x2 = 7
    //
    // x3 = 12
    // ----------------------------------------------------------

    imem[0] =
      enc_r(
        7'b0000000,
        2,
        1,
        3'b000,
        3,
        7'b0110011
      );

    // ----------------------------------------------------------
    // #2
    // PC = 0x00000004
    //
    // SUB x4,x2,x1
    //
    // 7 - 5 = 2
    // ----------------------------------------------------------

    imem[1] =
      enc_r(
        7'b0100000,
        1,
        2,
        3'b000,
        4,
        7'b0110011
      );

    // ----------------------------------------------------------
    // #3
    // PC = 0x00000008
    //
    // AND x5,x1,x2
    //
    // 5 AND 7 = 5
    // ----------------------------------------------------------

    imem[2] =
      enc_r(
        7'b0000000,
        2,
        1,
        3'b111,
        5,
        7'b0110011
      );

    // ----------------------------------------------------------
    // #4
    // PC = 0x0000000C
    //
    // OR x6,x1,x2
    //
    // 5 OR 7 = 7
    // ----------------------------------------------------------

    imem[3] =
      enc_r(
        7'b0000000,
        2,
        1,
        3'b110,
        6,
        7'b0110011
      );

    // ----------------------------------------------------------
    // #5
    // PC = 0x00000010
    //
    // LW x7,0(x0)
    //
    // x7 = DMEM[0]
    //    = 0x11223344
    // ----------------------------------------------------------

    imem[4] =
      enc_i(
        0,
        0,
        3'b010,
        7,
        7'b0000011
      );

    // ----------------------------------------------------------
    // #6
    // PC = 0x00000014
    //
    // SW x3,4(x0)
    //
    // DMEM[1] = x3 = 12
    // ----------------------------------------------------------

    imem[5] =
      enc_s(
        4,
        3,
        0,
        3'b010
      );

    // ----------------------------------------------------------
    // #7
    // PC = 0x00000018
    //
    // JAL x8,+8
    //
    // Link:
    //
    // x8 = 0x18 + 4
    //    = 0x1C
    //
    // Target:
    //
    // PC = 0x18 + 8
    //    = 0x20
    //
    // Therefore PC 0x1C is skipped.
    // ----------------------------------------------------------

    imem[6] =
      enc_j(
        8,
        8
      );

    // ----------------------------------------------------------
    // PC = 0x0000001C
    //
    // This NOP is NOT executed.
    // JAL skips it.
    // ----------------------------------------------------------

    imem[7] =
      32'h0000_0013;

    // ----------------------------------------------------------
    // #8
    // PC = 0x00000020
    //
    // LW x9,4(x0)
    //
    // Previous STORE wrote:
    //
    // DMEM[1] = 12
    //
    // therefore x9 = 12
    // ----------------------------------------------------------

    imem[8] =
      enc_i(
        4,
        0,
        3'b010,
        9,
        7'b0000011
      );

    // ==========================================================
    // RESET
    // ==========================================================

    repeat (4)
      @(posedge clk);

    /*
     * Release reset at negative edge so register initialization
     * occurs safely before the first active CPU rising edge.
     */
    @(negedge clk);

    rst = 1'b0;

    // ==========================================================
    // PRELOAD REGISTER FILE FOR THIS CYCLE-COUNT TEST
    // ==========================================================
    //
    // We directly initialize x1 and x2 in the TESTBENCH because
    // the user wants the FIRST FOUR executed instructions to be
    // R-Type instructions.
    //
    // This is simulation-only stimulus.
    // No RTL hardware is being changed.
    // ==========================================================

    dut.u_regfile.regs[1] = 32'd5;
    dut.u_regfile.regs[2] = 32'd7;

    // ==========================================================
    // EXECUTE AND COUNT ALL 8 INSTRUCTIONS
    // ==========================================================

    // #1 ADD
    check_instruction(
      1,
      32'h0000_0000,
      5,
      "ADD"
    );

    // #2 SUB
    check_instruction(
      2,
      32'h0000_0004,
      5,
      "SUB"
    );

    // #3 AND
    check_instruction(
      3,
      32'h0000_0008,
      5,
      "AND"
    );

    // #4 OR
    check_instruction(
      4,
      32'h0000_000C,
      5,
      "OR"
    );

    // #5 LOAD
    check_instruction(
      5,
      32'h0000_0010,
      7,
      "LW-1"
    );

    // #6 STORE
    check_instruction(
      6,
      32'h0000_0014,
      6,
      "SW"
    );

    // #7 JUMP
    check_instruction(
      7,
      32'h0000_0018,
      4,
      "JAL"
    );

    // #8 LOAD
    check_instruction(
      8,
      32'h0000_0020,
      7,
      "LW-2"
    );

    // ==========================================================
    // FUNCTIONAL RESULT CHECKS
    // ==========================================================

    // #1 ADD
    if (
      dut.u_regfile.regs[3] !==
      32'd12
    )
      $fatal(
        1,
        "ADD failed x3=%08x",
        dut.u_regfile.regs[3]
      );

    // #2 SUB
    if (
      dut.u_regfile.regs[4] !==
      32'd2
    )
      $fatal(
        1,
        "SUB failed x4=%08x",
        dut.u_regfile.regs[4]
      );

    // #3 AND
    if (
      dut.u_regfile.regs[5] !==
      32'd5
    )
      $fatal(
        1,
        "AND failed x5=%08x",
        dut.u_regfile.regs[5]
      );

    // #4 OR
    if (
      dut.u_regfile.regs[6] !==
      32'd7
    )
      $fatal(
        1,
        "OR failed x6=%08x",
        dut.u_regfile.regs[6]
      );

    // #5 LW
    if (
      dut.u_regfile.regs[7] !==
      32'h1122_3344
    )
      $fatal(
        1,
        "First LW failed x7=%08x",
        dut.u_regfile.regs[7]
      );

    // #6 SW
    if (
      dmem[1] !==
      32'd12
    )
      $fatal(
        1,
        "SW failed DMEM[1]=%08x",
        dmem[1]
      );

    // #7 JAL
    if (
      dut.u_regfile.regs[8] !==
      32'h0000_001C
    )
      $fatal(
        1,
        "JAL link failed x8=%08x",
        dut.u_regfile.regs[8]
      );

    // #8 second LW
    if (
      dut.u_regfile.regs[9] !==
      32'd12
    )
      $fatal(
        1,
        "Second LW failed x9=%08x",
        dut.u_regfile.regs[9]
      );

    // ==========================================================
    // FINAL CYCLE COUNT
    // ==========================================================

    if (instruction_count != 8)
      $fatal(
        1,
        "Expected 8 instructions, counted %0d",
        instruction_count
      );

    if (total_cycles != 44)
      $fatal(
        1,
        "Expected total 44 cycles, got %0d",
        total_cycles
      );

    // ==========================================================
    // FINAL DISPLAY
    // ==========================================================

    $display("");
    $display("");
    $display(
      "=========================================================================="
    );
    $display(
      "                    MULTICYCLE CPU CYCLE SUMMARY"
    );
    $display(
      "=========================================================================="
    );

    $display(
      " #     PC          Instruction        Type          Cycles"
    );

    $display(
      "--------------------------------------------------------------------------"
    );

    $display(
      " 1   00000000      ADD x3,x1,x2      R-Type          5"
    );

    $display(
      " 2   00000004      SUB x4,x2,x1      R-Type          5"
    );

    $display(
      " 3   00000008      AND x5,x1,x2      R-Type          5"
    );

    $display(
      " 4   0000000C      OR  x6,x1,x2      R-Type          5"
    );

    $display(
      " 5   00000010      LW  x7,0(x0)      LOAD            7"
    );

    $display(
      " 6   00000014      SW  x3,4(x0)      STORE           6"
    );

    $display(
      " 7   00000018      JAL x8,+8         JUMP            4"
    );

    $display(
      " 8   00000020      LW  x9,4(x0)      LOAD            7"
    );

    $display(
      "--------------------------------------------------------------------------"
    );

    $display(
      "Executed Instructions : %0d",
      instruction_count
    );

    $display(
      "Total Instruction Cycles : %0d",
      total_cycles
    );

    $display(
      "Final PC : 0x%08x",
      pc
    );

    $display(
      "=========================================================================="
    );

    $display(
      "[PASS] tb_core_cycle_count"
    );

    $display(
      "=========================================================================="
    );

    $finish;

  end

endmodule