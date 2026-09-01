module rv32i_decoder (
  input  logic [31:0] instr_i,
  output logic        reg_write_o,
  output logic        mem_valid_o,
  output logic        mem_write_o,
  output logic [3:0]  alu_op_o,
  output logic        alu_src_imm_o,
  output logic        alu_a_pc_o,
  output logic        alu_a_zero_o,
  output logic [2:0]  imm_sel_o,
  output logic [1:0]  wb_sel_o,
  output logic        branch_o,
  output logic        jal_o,
  output logic        jalr_o,
  output logic        ecall_o,
  output logic        ebreak_o,
  output logic        fence_o,
  output logic        illegal_o
);
  import soc_pkg::*;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instr_i[6:0];
  assign funct3 = instr_i[14:12];
  assign funct7 = instr_i[31:25];

  always_comb begin
    reg_write_o   = 1'b0;
    mem_valid_o   = 1'b0;
    mem_write_o   = 1'b0;
    alu_op_o      = ALU_ADD;
    alu_src_imm_o = 1'b0;
    alu_a_pc_o    = 1'b0;
    alu_a_zero_o  = 1'b0;
    imm_sel_o     = IMM_I;
    wb_sel_o      = WB_ALU;
    branch_o      = 1'b0;
    jal_o         = 1'b0;
    jalr_o        = 1'b0;
    ecall_o       = 1'b0;
    ebreak_o      = 1'b0;
    fence_o       = 1'b0;
    illegal_o     = 1'b0;

    case (opcode)
      7'b0110111: begin // LUI
        reg_write_o   = 1'b1;
        alu_src_imm_o = 1'b1;
        alu_a_zero_o  = 1'b1;
        imm_sel_o     = IMM_U;
        alu_op_o      = ALU_ADD;
      end

      7'b0010111: begin // AUIPC
        reg_write_o   = 1'b1;
        alu_src_imm_o = 1'b1;
        alu_a_pc_o    = 1'b1;
        imm_sel_o     = IMM_U;
        alu_op_o      = ALU_ADD;
      end

      7'b1101111: begin // JAL
        reg_write_o = 1'b1;
        imm_sel_o   = IMM_J;
        wb_sel_o    = WB_PC4;
        jal_o       = 1'b1;
      end

      7'b1100111: begin // JALR
        if (funct3 == 3'b000) begin
          reg_write_o   = 1'b1;
          alu_src_imm_o = 1'b1;
          imm_sel_o     = IMM_I;
          wb_sel_o      = WB_PC4;
          alu_op_o      = ALU_ADD;
          jalr_o        = 1'b1;
        end else begin
          illegal_o = 1'b1;
        end
      end

      7'b1100011: begin // BRANCH
        imm_sel_o = IMM_B;
        case (funct3)
          3'b000, // BEQ
          3'b001, // BNE
          3'b100, // BLT
          3'b101, // BGE
          3'b110, // BLTU
          3'b111: branch_o = 1'b1; // BGEU
          default: illegal_o = 1'b1;
        endcase
      end

      7'b0000011: begin // LOAD
        case (funct3)
          3'b000, 3'b001, 3'b010, 3'b100, 3'b101: begin
            reg_write_o   = 1'b1;
            mem_valid_o   = 1'b1;
            mem_write_o   = 1'b0;
            alu_src_imm_o = 1'b1;
            imm_sel_o     = IMM_I;
            wb_sel_o      = WB_MEM;
            alu_op_o      = ALU_ADD;
          end
          default: illegal_o = 1'b1;
        endcase
      end

      7'b0100011: begin // STORE
        case (funct3)
          3'b000, 3'b001, 3'b010: begin
            mem_valid_o   = 1'b1;
            mem_write_o   = 1'b1;
            alu_src_imm_o = 1'b1;
            imm_sel_o     = IMM_S;
            alu_op_o      = ALU_ADD;
          end
          default: illegal_o = 1'b1;
        endcase
      end

      7'b0010011: begin // OP-IMM
        reg_write_o   = 1'b1;
        alu_src_imm_o = 1'b1;
        imm_sel_o     = IMM_I;
        case (funct3)
          3'b000: alu_op_o = ALU_ADD;  // ADDI
          3'b010: alu_op_o = ALU_SLT;  // SLTI
          3'b011: alu_op_o = ALU_SLTU; // SLTIU
          3'b100: alu_op_o = ALU_XOR;  // XORI
          3'b110: alu_op_o = ALU_OR;   // ORI
          3'b111: alu_op_o = ALU_AND;  // ANDI
          3'b001: begin // SLLI
            if (funct7 == 7'b0000000)
              alu_op_o = ALU_SLL;
            else
              illegal_o = 1'b1;
          end
          3'b101: begin // SRLI / SRAI
            if (funct7 == 7'b0000000)
              alu_op_o = ALU_SRL;
            else if (funct7 == 7'b0100000)
              alu_op_o = ALU_SRA;
            else
              illegal_o = 1'b1;
          end
          default: illegal_o = 1'b1;
        endcase
      end

      7'b0110011: begin // OP
        reg_write_o = 1'b1;
        case (funct3)
          3'b000: begin
            if (funct7 == 7'b0000000)
              alu_op_o = ALU_ADD;
            else if (funct7 == 7'b0100000)
              alu_op_o = ALU_SUB;
            else
              illegal_o = 1'b1;
          end
          3'b001: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_SLL; else illegal_o = 1'b1;
          end
          3'b010: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_SLT; else illegal_o = 1'b1;
          end
          3'b011: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_SLTU; else illegal_o = 1'b1;
          end
          3'b100: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_XOR; else illegal_o = 1'b1;
          end
          3'b101: begin
            if (funct7 == 7'b0000000)
              alu_op_o = ALU_SRL;
            else if (funct7 == 7'b0100000)
              alu_op_o = ALU_SRA;
            else
              illegal_o = 1'b1;
          end
          3'b110: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_OR; else illegal_o = 1'b1;
          end
          3'b111: begin
            if (funct7 == 7'b0000000) alu_op_o = ALU_AND; else illegal_o = 1'b1;
          end
          default: illegal_o = 1'b1;
        endcase
      end

      7'b0001111: begin // FENCE (base RV32I): implemented as an in-order no-op.
        if (funct3 == 3'b000)
          fence_o = 1'b1;
        else
          illegal_o = 1'b1;
      end

      7'b1110011: begin // SYSTEM: base ECALL / EBREAK only; CSRs are extensions.
        if (instr_i == 32'h0000_0073)
          ecall_o = 1'b1;
        else if (instr_i == 32'h0010_0073)
          ebreak_o = 1'b1;
        else
          illegal_o = 1'b1;
      end

      default: illegal_o = 1'b1;
    endcase

    // Never write architectural state for an illegal encoding.
    if (illegal_o) begin
      reg_write_o = 1'b0;
      mem_valid_o = 1'b0;
      mem_write_o = 1'b0;
      branch_o    = 1'b0;
      jal_o       = 1'b0;
      jalr_o      = 1'b0;
    end
  end
endmodule
