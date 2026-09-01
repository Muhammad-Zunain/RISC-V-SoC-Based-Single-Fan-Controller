module rv32i_core #(
  parameter logic [31:0] RESET_PC_P = 32'h0000_0000
) (
  input  logic        clk_i,
  input  logic        rst_i,

  // ------------------------------------------------------------
  // Instruction memory request/response interface
  // ------------------------------------------------------------
  output logic        imem_req_o,
  output logic [31:0] imem_addr_o,
  input  logic        imem_ready_i,
  input  logic [31:0] imem_rdata_i,
  input  logic        imem_fault_i,

  // ------------------------------------------------------------
  // Data / MMIO request/response interface
  // ------------------------------------------------------------
  output logic        dmem_req_o,
  output logic        dmem_write_o,
  output logic [31:0] dmem_addr_o,
  output logic [31:0] dmem_wdata_o,
  output logic [3:0]  dmem_wstrb_o,

  input  logic        dmem_ready_i,
  input  logic [31:0] dmem_rdata_i,
  input  logic        dmem_fault_i,

  // ------------------------------------------------------------
  // Debug outputs
  // ------------------------------------------------------------
  output logic [31:0] pc_o,
  output logic [31:0] instr_o,
  output logic        halted_o,
  output logic        trap_o,
  output logic [31:0] trap_cause_o,
  output logic [3:0]  state_o
);

  import soc_pkg::*;

  // ============================================================
  // MULTICYCLE FSM STATES
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

  logic [3:0] state_q;
  logic [3:0] state_d;

  // ============================================================
  // Architectural / intermediate registers
  // ============================================================

  logic [31:0] pc_q;
  logic [31:0] instr_q;

  /*
   * These values are captured during DECODE.
   * They remain stable while the instruction moves through
   * later multicycle states.
   */
  logic [31:0] rs1_q;
  logic [31:0] rs2_q;
  logic [31:0] imm_q;

  /*
   * Intermediate execution / memory registers.
   */
  logic [31:0] alu_result_q;

  logic [31:0] effective_addr_q;

  logic [31:0] store_wdata_q;
  logic [3:0]  store_wstrb_q;

  logic [31:0] load_data_q;

  // ============================================================
  // Register file signals
  // ============================================================

  logic [4:0] rs1_addr;
  logic [4:0] rs2_addr;
  logic [4:0] rd_addr;

  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  logic        regfile_we;
  logic [31:0] regfile_wdata;

  // ============================================================
  // Decoder outputs
  // ============================================================

  logic       dec_reg_write;
  logic       dec_mem_valid;
  logic       dec_mem_write;

  logic [3:0] dec_alu_op;

  logic       dec_alu_src_imm;
  logic       dec_alu_a_pc;
  logic       dec_alu_a_zero;

  logic [2:0] dec_imm_sel;
  logic [1:0] dec_wb_sel;

  logic       dec_branch;
  logic       dec_jal;
  logic       dec_jalr;

  logic       dec_ecall;
  logic       dec_ebreak;
  logic       dec_fence;
  logic       dec_illegal;

  // ============================================================
  // Immediate generator
  // ============================================================

  logic [31:0] imm_comb;

  // ============================================================
  // ALU
  // ============================================================

  logic [31:0] alu_a;
  logic [31:0] alu_b;
  logic [31:0] alu_y;

  // ============================================================
  // Branch logic
  // ============================================================

  logic branch_taken;

  // ============================================================
  // LSU
  // ============================================================

  logic        mem_misaligned;

  logic [31:0] store_wdata_comb;
  logic [3:0]  store_wstrb_comb;

  logic [31:0] load_data_comb;

  // ============================================================
  // Control-flow signals
  // ============================================================

  logic [31:0] control_target;
  logic        control_transfer;
  logic        control_target_misaligned;

  // ============================================================
  // Trap / exception signals
  // ============================================================

  logic        trap_request;
  logic [31:0] trap_cause_next;

  // ============================================================
  // Debug assignments
  // ============================================================

  assign pc_o    = pc_q;
  assign instr_o = instr_q;
  assign state_o = state_q;

  // ============================================================
  // Instruction register fields
  // ============================================================

  assign rs1_addr = instr_q[19:15];
  assign rs2_addr = instr_q[24:20];
  assign rd_addr  = instr_q[11:7];

  // ============================================================
  // RV32I Decoder
  // ============================================================

  rv32i_decoder u_decoder (
    .instr_i          (instr_q),

    .reg_write_o      (dec_reg_write),

    .mem_valid_o      (dec_mem_valid),
    .mem_write_o      (dec_mem_write),

    .alu_op_o         (dec_alu_op),

    .alu_src_imm_o    (dec_alu_src_imm),
    .alu_a_pc_o       (dec_alu_a_pc),
    .alu_a_zero_o     (dec_alu_a_zero),

    .imm_sel_o        (dec_imm_sel),
    .wb_sel_o         (dec_wb_sel),

    .branch_o         (dec_branch),
    .jal_o            (dec_jal),
    .jalr_o           (dec_jalr),

    .ecall_o          (dec_ecall),
    .ebreak_o         (dec_ebreak),
    .fence_o          (dec_fence),

    .illegal_o        (dec_illegal)
  );

  // ============================================================
  // Immediate Generator
  // ============================================================

  rv32i_imm_gen u_imm_gen (
    .instr_i (instr_q),
    .sel_i   (dec_imm_sel),
    .imm_o   (imm_comb)
  );

  // ============================================================
  // Register File
  // ============================================================

  rv32i_regfile u_regfile (
    .clk_i       (clk_i),
    .rst_i       (rst_i),

    .rs1_addr_i  (rs1_addr),
    .rs2_addr_i  (rs2_addr),

    .rs1_data_o  (rs1_data),
    .rs2_data_o  (rs2_data),

    .rd_we_i     (regfile_we),
    .rd_addr_i   (rd_addr),
    .rd_data_i   (regfile_wdata)
  );

  // ============================================================
  // ALU input selection
  // ============================================================

  always_comb begin

    if (dec_alu_a_zero)
      alu_a = 32'd0;

    else if (dec_alu_a_pc)
      alu_a = pc_q;

    else
      alu_a = rs1_q;

    alu_b =
      dec_alu_src_imm ?
      imm_q :
      rs2_q;

  end

  // ============================================================
  // ALU
  // ============================================================

  rv32i_alu u_alu (
    .a_i  (alu_a),
    .b_i  (alu_b),
    .op_i (dec_alu_op),
    .y_o  (alu_y)
  );

  // ============================================================
  // Branch Unit
  // ============================================================

  rv32i_branch_unit u_branch (
    .funct3_i (instr_q[14:12]),
    .rs1_i    (rs1_q),
    .rs2_i    (rs2_q),
    .taken_o  (branch_taken)
  );

  // ============================================================
  // Load Store Unit
  // ============================================================

  /*
   * During EXECUTE:
   *   alu_y contains the newly calculated effective address.
   *
   * During MEM_WAIT / LOAD_WB:
   *   use the stored effective address.
   */
  rv32i_lsu u_lsu (
    .mem_valid_i (
      dec_mem_valid
    ),

    .mem_write_i (
      dec_mem_write
    ),

    .funct3_i (
      instr_q[14:12]
    ),

    .addr_i (
      (state_q == ST_MEM_WAIT ||
       state_q == ST_LOAD_WB)
      ?
      effective_addr_q
      :
      alu_y
    ),

    .rs2_i (
      rs2_q
    ),

    .rdata_i (
      dmem_rdata_i
    ),

    .misaligned_o (
      mem_misaligned
    ),

    .store_wdata_o (
      store_wdata_comb
    ),

    .store_wstrb_o (
      store_wstrb_comb
    ),

    .load_data_o (
      load_data_comb
    )
  );

  // ============================================================
  // Branch / Jump target calculation
  // ============================================================

  always_comb begin

    control_transfer = 1'b0;
    control_target   = pc_q + 32'd4;

    // ----------------------------------------------------------
    // JAL
    // ----------------------------------------------------------

    if (dec_jal) begin

      control_transfer = 1'b1;

      control_target =
        pc_q +
        imm_q;

    end

    // ----------------------------------------------------------
    // JALR
    // ----------------------------------------------------------

    else if (dec_jalr) begin

      control_transfer = 1'b1;

      control_target =
        (rs1_q + imm_q)
        &
        32'hFFFF_FFFE;

    end

    // ----------------------------------------------------------
    // Conditional Branch
    // ----------------------------------------------------------

    else if (
      dec_branch &&
      branch_taken
    ) begin

      control_transfer = 1'b1;

      control_target =
        pc_q +
        imm_q;

    end

  end

  /*
   * RV32I without compressed instructions requires
   * instruction addresses to be 4-byte aligned.
   */
  assign control_target_misaligned =
      control_transfer &&
      (control_target[1:0] != 2'b00);

  // ============================================================
  // Instruction/Data request generation
  // ============================================================

  /*
   * Requests are generated only in explicit request states.
   *
   * FETCH_REQ:
   *   Start instruction SRAM transaction.
   *
   * MEM_REQ:
   *   Start Data SRAM / Config SRAM / MMIO transaction.
   */
  always_comb begin

    // Defaults
    imem_req_o  = 1'b0;
    imem_addr_o = pc_q;

    dmem_req_o   = 1'b0;
    dmem_write_o = dec_mem_write;

    dmem_addr_o  = effective_addr_q;
    dmem_wdata_o = store_wdata_q;
    dmem_wstrb_o = store_wstrb_q;

    if (!halted_o && !rst_i) begin

      if (state_q == ST_FETCH_REQ)
        imem_req_o = 1'b1;

      if (state_q == ST_MEM_REQ)
        dmem_req_o = 1'b1;

    end

  end

  // ============================================================
  // Register File Writeback
  // ============================================================

  /*
   * IMPORTANT UPDATE:
   *
   * Previously:
   *
   *     if (!halted_o)
   *
   * Now:
   *
   *     if (!halted_o && !trap_request)
   *
   * This prevents JAL/JALR or any other architectural
   * writeback from modifying the register file when the
   * current instruction is simultaneously taking a trap.
   */
  always_comb begin

    regfile_we    = 1'b0;
    regfile_wdata = 32'd0;

    // ==========================================================
    // UPDATED CONDITION
    // ==========================================================

    if (!halted_o && !trap_request) begin

      // --------------------------------------------------------
      // ALU instruction writeback
      // --------------------------------------------------------

      if (
        state_q == ST_ALU_WB &&
        dec_reg_write
      ) begin

        regfile_we =
          1'b1;

        regfile_wdata =
          alu_result_q;

      end

      // --------------------------------------------------------
      // LOAD writeback
      // --------------------------------------------------------

      else if (
        state_q == ST_LOAD_WB &&
        dec_reg_write
      ) begin

        regfile_we =
          1'b1;

        regfile_wdata =
          load_data_q;

      end

      // --------------------------------------------------------
      // JAL / JALR link-register writeback
      // --------------------------------------------------------

      else if (
        state_q == ST_EXECUTE &&
        (dec_jal || dec_jalr) &&
        dec_reg_write
      ) begin

        regfile_we =
          1'b1;

        regfile_wdata =
          pc_q + 32'd4;

      end

    end

  end

  // ============================================================
  // FSM NEXT-STATE LOGIC
  // ============================================================

  always_comb begin

    state_d = state_q;

    case (state_q)

      // --------------------------------------------------------
      // Start instruction-memory transaction
      // --------------------------------------------------------

      ST_FETCH_REQ: begin

        state_d =
          ST_FETCH_WAIT;

      end

      // --------------------------------------------------------
      // Wait for synchronous instruction SRAM
      // --------------------------------------------------------

      ST_FETCH_WAIT: begin

        if (imem_ready_i)
          state_d =
            ST_DECODE;

      end

      // --------------------------------------------------------
      // Decode instruction
      // --------------------------------------------------------

      ST_DECODE: begin

        if (!(
          dec_illegal ||
          dec_ecall ||
          dec_ebreak
        ))
          state_d =
            ST_EXECUTE;

      end

      // --------------------------------------------------------
      // Execute instruction
      // --------------------------------------------------------

      ST_EXECUTE: begin

        // Memory instruction
        if (dec_mem_valid) begin

          if (!mem_misaligned)
            state_d =
              ST_MEM_REQ;

        end

        // Branch / Jump / Fence
        else if (
          dec_branch ||
          dec_jal ||
          dec_jalr ||
          dec_fence
        ) begin

          state_d =
            ST_FETCH_REQ;

        end

        // ALU/register instruction
        else if (dec_reg_write) begin

          state_d =
            ST_ALU_WB;

        end

        else begin

          state_d =
            ST_FETCH_REQ;

        end

      end

      // --------------------------------------------------------
      // ALU register writeback
      // --------------------------------------------------------

      ST_ALU_WB: begin

        state_d =
          ST_FETCH_REQ;

      end

      // --------------------------------------------------------
      // Start Data/MMIO transaction
      // --------------------------------------------------------

      ST_MEM_REQ: begin

        state_d =
          ST_MEM_WAIT;

      end

      // --------------------------------------------------------
      // Wait for Data SRAM/MMIO acknowledgement
      // --------------------------------------------------------

      ST_MEM_WAIT: begin

        if (dmem_ready_i) begin

          if (dec_mem_write)
            state_d =
              ST_FETCH_REQ;

          else
            state_d =
              ST_LOAD_WB;

        end

      end

      // --------------------------------------------------------
      // Load result writeback
      // --------------------------------------------------------

      ST_LOAD_WB: begin

        state_d =
          ST_FETCH_REQ;

      end

      // --------------------------------------------------------
      // Trap / halted state
      // --------------------------------------------------------

      ST_TRAP: begin

        state_d =
          ST_TRAP;

      end

      default: begin

        state_d =
          ST_TRAP;

      end

    endcase

  end

  // ============================================================
  // Trap / Exception Detection
  // ============================================================

  always_comb begin

    trap_request    = 1'b0;
    trap_cause_next = 32'd0;

    if (!halted_o) begin

      case (state_q)

        // ------------------------------------------------------
        // Instruction address misalignment
        // ------------------------------------------------------

        ST_FETCH_REQ: begin

          if (pc_q[1:0] != 2'b00) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_INSTR_MISALIGNED;

          end

        end

        // ------------------------------------------------------
        // Instruction SRAM access fault
        // ------------------------------------------------------

        ST_FETCH_WAIT: begin

          if (
            imem_ready_i &&
            imem_fault_i
          ) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_INSTR_ACCESS;

          end

        end

        // ------------------------------------------------------
        // Decode exceptions
        // ------------------------------------------------------

        ST_DECODE: begin

          if (dec_illegal) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_ILLEGAL_INSTR;

          end

          else if (dec_ebreak) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_BREAKPOINT;

          end

          else if (dec_ecall) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_ECALL;

          end

        end

        // ------------------------------------------------------
        // Execute-stage exceptions
        // ------------------------------------------------------

        ST_EXECUTE: begin

          // Branch/JAL/JALR target misalignment
          if (control_target_misaligned) begin

            trap_request =
              1'b1;

            trap_cause_next =
              CAUSE_INSTR_MISALIGNED;

          end

          // Load/store misalignment
          else if (
            dec_mem_valid &&
            mem_misaligned
          ) begin

            trap_request =
              1'b1;

            trap_cause_next =
              dec_mem_write
              ?
              CAUSE_STORE_MISALIGNED
              :
              CAUSE_LOAD_MISALIGNED;

          end

        end

        // ------------------------------------------------------
        // Data/MMIO access fault
        // ------------------------------------------------------

        ST_MEM_WAIT: begin

          if (
            dmem_ready_i &&
            dmem_fault_i
          ) begin

            trap_request =
              1'b1;

            trap_cause_next =
              dec_mem_write
              ?
              CAUSE_STORE_ACCESS
              :
              CAUSE_LOAD_ACCESS;

          end

        end

        default: begin
        end

      endcase

    end

  end

  // ============================================================
  // SEQUENTIAL STATE / DATAPATH REGISTERS
  // ============================================================

  always_ff @(posedge clk_i) begin

    // ==========================================================
    // RESET
    // ==========================================================

    if (rst_i) begin

      state_q <=
        ST_FETCH_REQ;

      pc_q <=
        RESET_PC_P;

      /*
       * Initialize instruction register with:
       *
       * ADDI x0,x0,0
       *
       * which is the standard RV32I NOP.
       */
      instr_q <=
        32'h0000_0013;

      rs1_q <=
        32'd0;

      rs2_q <=
        32'd0;

      imm_q <=
        32'd0;

      alu_result_q <=
        32'd0;

      effective_addr_q <=
        32'd0;

      store_wdata_q <=
        32'd0;

      store_wstrb_q <=
        4'd0;

      load_data_q <=
        32'd0;

      halted_o <=
        1'b0;

      trap_o <=
        1'b0;

      trap_cause_o <=
        32'd0;

    end

    // ==========================================================
    // NORMAL OPERATION
    // ==========================================================

    else if (!halted_o) begin

      // --------------------------------------------------------
      // Trap has priority over normal architectural updates.
      // --------------------------------------------------------

      if (trap_request) begin

        state_q <=
          ST_TRAP;

        halted_o <=
          1'b1;

        trap_o <=
          1'b1;

        trap_cause_o <=
          trap_cause_next;

      end

      // --------------------------------------------------------
      // Normal instruction processing
      // --------------------------------------------------------

      else begin

        state_q <=
          state_d;

        // ======================================================
        // FETCH_WAIT
        // ======================================================

        /*
         * Capture instruction only when synchronous instruction
         * memory returns ready.
         */
        if (
          state_q == ST_FETCH_WAIT &&
          imem_ready_i
        ) begin

          instr_q <=
            imem_rdata_i;

        end

        // ======================================================
        // DECODE
        // ======================================================

        /*
         * Capture source operands and immediate.
         */
        if (state_q == ST_DECODE) begin

          rs1_q <=
            rs1_data;

          rs2_q <=
            rs2_data;

          imm_q <=
            imm_comb;

        end

        // ======================================================
        // EXECUTE
        // ======================================================

        if (state_q == ST_EXECUTE) begin

          /*
           * Memory instruction:
           * capture address/write-data/write-strobes.
           */
          if (
            dec_mem_valid &&
            !mem_misaligned
          ) begin

            effective_addr_q <=
              alu_y;

            store_wdata_q <=
              store_wdata_comb;

            store_wstrb_q <=
              store_wstrb_comb;

          end

          /*
           * Non-memory register-writing instruction:
           * capture ALU result for ALU_WB.
           */
          else if (
            dec_reg_write &&
            !(dec_jal || dec_jalr)
          ) begin

            alu_result_q <=
              alu_y;

          end

          // ----------------------------------------------------
          // Branch / Jump PC update
          // ----------------------------------------------------

          if (
            dec_branch ||
            dec_jal ||
            dec_jalr
          ) begin

            if (control_transfer)
              pc_q <=
                control_target;

            else
              pc_q <=
                pc_q + 32'd4;

          end

          // ----------------------------------------------------
          // FENCE behaves as a completed sequential instruction.
          // ----------------------------------------------------

          else if (dec_fence) begin

            pc_q <=
              pc_q + 32'd4;

          end

        end

        // ======================================================
        // ALU WRITEBACK
        // ======================================================

        if (state_q == ST_ALU_WB) begin

          pc_q <=
            pc_q + 32'd4;

        end

        // ======================================================
        // MEMORY RESPONSE
        // ======================================================

        if (
          state_q == ST_MEM_WAIT &&
          dmem_ready_i
        ) begin

          // ----------------------------------------------------
          // STORE completed
          // ----------------------------------------------------

          if (dec_mem_write) begin

            pc_q <=
              pc_q + 32'd4;

          end

          // ----------------------------------------------------
          // LOAD completed
          // ----------------------------------------------------

          else begin

            load_data_q <=
              load_data_comb;

          end

        end

        // ======================================================
        // LOAD WRITEBACK
        // ======================================================

        if (state_q == ST_LOAD_WB) begin

          pc_q <=
            pc_q + 32'd4;

        end

      end

    end

  end

endmodule