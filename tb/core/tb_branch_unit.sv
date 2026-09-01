`timescale 1ns/1ps
module tb_branch_unit;
  logic [2:0] funct3;
  logic [31:0] a,b;
  logic taken;
  rv32i_branch_unit dut(.funct3_i(funct3),.rs1_i(a),.rs2_i(b),.taken_o(taken));

  task automatic chk(input [2:0] f,input [31:0] aa,input [31:0] bb,input logic exp,input string n);
    begin funct3=f;a=aa;b=bb;#1;if(taken!==exp)$fatal(1,"%s failed",n);end
  endtask

  initial begin
    chk(3'b000,5,5,1,"BEQ taken"); chk(3'b000,5,6,0,"BEQ not");
    chk(3'b001,5,6,1,"BNE taken"); chk(3'b001,5,5,0,"BNE not");
    chk(3'b100,32'hffff_ffff,1,1,"BLT signed");
    chk(3'b101,1,32'hffff_ffff,1,"BGE signed");
    chk(3'b110,1,32'hffff_ffff,1,"BLTU");
    chk(3'b111,32'hffff_ffff,1,1,"BGEU");
    $display("[PASS] tb_branch_unit"); $finish;
  end
endmodule
