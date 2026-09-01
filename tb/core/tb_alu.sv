`timescale 1ns/1ps
module tb_alu;
  import soc_pkg::*;
  logic [31:0] a, b, y;
  logic [3:0] op;

  rv32i_alu dut(.a_i(a), .b_i(b), .op_i(op), .y_o(y));

  task automatic check(input [31:0] aa, input [31:0] bb,
                       input [3:0] oo, input [31:0] exp,
                       input string name);
    begin
      a = aa; b = bb; op = oo; #1;
      if (y !== exp) $fatal(1, "%s failed: a=%08x b=%08x y=%08x exp=%08x", name, a, b, y, exp);
    end
  endtask

  initial begin
    check(32'd5, 32'd7, ALU_ADD, 32'd12, "ADD");
    check(32'd12, 32'd5, ALU_SUB, 32'd7, "SUB");
    check(32'h0000_0003, 32'd4, ALU_SLL, 32'h0000_0030, "SLL");
    check(32'hffff_ffff, 32'd1, ALU_SLT, 32'd1, "SLT signed");
    check(32'hffff_ffff, 32'd1, ALU_SLTU, 32'd0, "SLTU unsigned");
    check(32'h55aa_00ff, 32'h0f0f_f0f0, ALU_XOR, 32'h5aa5_f00f, "XOR");
    check(32'h8000_0000, 32'd4, ALU_SRL, 32'h0800_0000, "SRL");
    check(32'h8000_0000, 32'd4, ALU_SRA, 32'hf800_0000, "SRA");
    check(32'h5500_00aa, 32'h00ff_ff00, ALU_OR, 32'h55ff_ffaa, "OR");
    check(32'h55ff_00aa, 32'h0ff0_0ff0, ALU_AND, 32'h05f0_00a0, "AND");
    $display("[PASS] tb_alu");
    $finish;
  end
endmodule
