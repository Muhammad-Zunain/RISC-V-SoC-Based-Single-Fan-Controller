`timescale 1ns/1ps
module tb_imm_gen;
  import soc_pkg::*;
  logic [31:0] instr, imm;
  logic [2:0] sel;
  `include "tb/common/rv32i_encode.svh"

  rv32i_imm_gen dut(.instr_i(instr), .sel_i(sel), .imm_o(imm));

  initial begin
    instr = enc_i(-7, 5'd1, 3'b000, 5'd2, 7'b0010011); sel=IMM_I; #1;
    if (imm !== 32'hffff_fff9) $fatal(1,"I immediate failed %08x",imm);

    instr = enc_s(-12, 5'd2, 5'd1, 3'b010); sel=IMM_S; #1;
    if (imm !== 32'hffff_fff4) $fatal(1,"S immediate failed %08x",imm);

    instr = enc_b(-16, 5'd2, 5'd1, 3'b000); sel=IMM_B; #1;
    if (imm !== 32'hffff_fff0) $fatal(1,"B immediate failed %08x",imm);

    instr = enc_u(20'habcde, 5'd3, 7'b0110111); sel=IMM_U; #1;
    if (imm !== 32'habcde000) $fatal(1,"U immediate failed %08x",imm);

    instr = enc_j(2046, 5'd1); sel=IMM_J; #1;
    if (imm !== 32'd2046) $fatal(1,"J immediate failed %08x",imm);

    instr = enc_j(-2048, 5'd1); sel=IMM_J; #1;
    if (imm !== 32'hffff_f800) $fatal(1,"negative J immediate failed %08x",imm);

    $display("[PASS] tb_imm_gen");
    $finish;
  end
endmodule
