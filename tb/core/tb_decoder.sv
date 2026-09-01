`timescale 1ns/1ps
module tb_decoder;
  import soc_pkg::*;
  logic [31:0] instr;
  logic reg_write,mem_valid,mem_write,alu_src_imm,alu_a_pc,alu_a_zero;
  logic [3:0] alu_op;
  logic [2:0] imm_sel;
  logic [1:0] wb_sel;
  logic branch,jal,jalr,ecall,ebreak,fence,illegal;
  `include "tb/common/rv32i_encode.svh"

  rv32i_decoder dut(
    .instr_i(instr),.reg_write_o(reg_write),.mem_valid_o(mem_valid),.mem_write_o(mem_write),
    .alu_op_o(alu_op),.alu_src_imm_o(alu_src_imm),.alu_a_pc_o(alu_a_pc),.alu_a_zero_o(alu_a_zero),
    .imm_sel_o(imm_sel),.wb_sel_o(wb_sel),.branch_o(branch),.jal_o(jal),.jalr_o(jalr),
    .ecall_o(ecall),.ebreak_o(ebreak),.fence_o(fence),.illegal_o(illegal));

  task automatic must_legal(input [31:0] ins, input string name);
    begin instr=ins;#1;if(illegal)$fatal(1,"%s decoded illegal (%08x)",name,ins);end
  endtask
  task automatic must_illegal(input [31:0] ins, input string name);
    begin instr=ins;#1;if(!illegal)$fatal(1,"%s should be illegal (%08x)",name,ins);
      if(reg_write||mem_valid||mem_write||branch||jal||jalr)$fatal(1,"illegal instruction has side effect controls");end
  endtask

  initial begin
    must_legal(enc_u(20'h12345,1,7'b0110111),"LUI"); if(!reg_write||!alu_a_zero||imm_sel!=IMM_U)$fatal(1,"LUI controls");
    must_legal(enc_u(20'h12345,1,7'b0010111),"AUIPC"); if(!reg_write||!alu_a_pc||imm_sel!=IMM_U)$fatal(1,"AUIPC controls");
    must_legal(enc_j(16,1),"JAL"); if(!jal||wb_sel!=WB_PC4)$fatal(1,"JAL controls");
    must_legal(enc_i(4,2,3'b000,1,7'b1100111),"JALR"); if(!jalr||wb_sel!=WB_PC4)$fatal(1,"JALR controls");

    must_legal(enc_b(8,2,1,3'b000),"BEQ"); if(!branch)$fatal(1,"BEQ control");
    must_legal(enc_b(8,2,1,3'b001),"BNE");
    must_legal(enc_b(8,2,1,3'b100),"BLT");
    must_legal(enc_b(8,2,1,3'b101),"BGE");
    must_legal(enc_b(8,2,1,3'b110),"BLTU");
    must_legal(enc_b(8,2,1,3'b111),"BGEU");

    must_legal(enc_i(0,1,3'b000,2,7'b0000011),"LB");
    must_legal(enc_i(0,1,3'b001,2,7'b0000011),"LH");
    must_legal(enc_i(0,1,3'b010,2,7'b0000011),"LW");
    must_legal(enc_i(0,1,3'b100,2,7'b0000011),"LBU");
    must_legal(enc_i(0,1,3'b101,2,7'b0000011),"LHU");
    if(!mem_valid||mem_write||wb_sel!=WB_MEM)$fatal(1,"LOAD controls");

    must_legal(enc_s(0,2,1,3'b000),"SB");
    must_legal(enc_s(0,2,1,3'b001),"SH");
    must_legal(enc_s(0,2,1,3'b010),"SW"); if(!mem_valid||!mem_write)$fatal(1,"STORE controls");

    must_legal(enc_i(1,1,3'b000,2,7'b0010011),"ADDI"); if(alu_op!=ALU_ADD)$fatal(1,"ADDI alu");
    must_legal(enc_i(1,1,3'b010,2,7'b0010011),"SLTI"); if(alu_op!=ALU_SLT)$fatal(1,"SLTI alu");
    must_legal(enc_i(1,1,3'b011,2,7'b0010011),"SLTIU"); if(alu_op!=ALU_SLTU)$fatal(1,"SLTIU alu");
    must_legal(enc_i(1,1,3'b100,2,7'b0010011),"XORI"); if(alu_op!=ALU_XOR)$fatal(1,"XORI alu");
    must_legal(enc_i(1,1,3'b110,2,7'b0010011),"ORI"); if(alu_op!=ALU_OR)$fatal(1,"ORI alu");
    must_legal(enc_i(1,1,3'b111,2,7'b0010011),"ANDI"); if(alu_op!=ALU_AND)$fatal(1,"ANDI alu");
    must_legal(enc_i(3,1,3'b001,2,7'b0010011),"SLLI"); if(alu_op!=ALU_SLL)$fatal(1,"SLLI alu");
    must_legal(enc_i(3,1,3'b101,2,7'b0010011),"SRLI"); if(alu_op!=ALU_SRL)$fatal(1,"SRLI alu");
    must_legal(enc_i(12'h403,1,3'b101,2,7'b0010011),"SRAI"); if(alu_op!=ALU_SRA)$fatal(1,"SRAI alu");

    must_legal(enc_r(7'b0000000,2,1,3'b000,3,7'b0110011),"ADD");
    must_legal(enc_r(7'b0100000,2,1,3'b000,3,7'b0110011),"SUB");
    must_legal(enc_r(7'b0000000,2,1,3'b001,3,7'b0110011),"SLL");
    must_legal(enc_r(7'b0000000,2,1,3'b010,3,7'b0110011),"SLT");
    must_legal(enc_r(7'b0000000,2,1,3'b011,3,7'b0110011),"SLTU");
    must_legal(enc_r(7'b0000000,2,1,3'b100,3,7'b0110011),"XOR");
    must_legal(enc_r(7'b0000000,2,1,3'b101,3,7'b0110011),"SRL");
    must_legal(enc_r(7'b0100000,2,1,3'b101,3,7'b0110011),"SRA");
    must_legal(enc_r(7'b0000000,2,1,3'b110,3,7'b0110011),"OR");
    must_legal(enc_r(7'b0000000,2,1,3'b111,3,7'b0110011),"AND");

    must_legal(32'h0000_000f,"FENCE"); if(!fence)$fatal(1,"FENCE control");
    must_legal(32'h0000_0073,"ECALL"); if(!ecall)$fatal(1,"ECALL control");
    must_legal(32'h0010_0073,"EBREAK"); if(!ebreak)$fatal(1,"EBREAK control");

    must_illegal(32'hffff_ffff,"unknown opcode");
    must_illegal(enc_i(0,1,3'b011,2,7'b0000011),"invalid LOAD funct3");
    must_illegal(enc_r(7'b1111111,2,1,3'b000,3,7'b0110011),"invalid OP funct7");
    must_illegal(enc_i(0,1,3'b001,2,7'b1100111),"invalid JALR funct3");

    $display("[PASS] tb_decoder"); $finish;
  end
endmodule
