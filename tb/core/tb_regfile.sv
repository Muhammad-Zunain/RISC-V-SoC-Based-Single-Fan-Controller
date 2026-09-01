`timescale 1ns/1ps
module tb_regfile;
  logic clk = 0, rst = 1;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic [31:0] rs1_data, rs2_data, rd_data;
  logic rd_we;

  always #5 clk = ~clk;

  rv32i_regfile dut(
    .clk_i(clk), .rst_i(rst),
    .rs1_addr_i(rs1_addr), .rs2_addr_i(rs2_addr),
    .rs1_data_o(rs1_data), .rs2_data_o(rs2_data),
    .rd_we_i(rd_we), .rd_addr_i(rd_addr), .rd_data_i(rd_data)
  );

  task automatic write_reg(input [4:0] a, input [31:0] d);
    begin
      @(negedge clk); rd_we = 1; rd_addr = a; rd_data = d;
      @(negedge clk); rd_we = 0;
    end
  endtask

  initial begin
    rs1_addr=0; rs2_addr=0; rd_we=0; rd_addr=0; rd_data=0;
    repeat(2) @(posedge clk); @(negedge clk); rst=0;

    write_reg(5'd1, 32'h1234_5678);
    write_reg(5'd31, 32'hcafe_babe);
    rs1_addr=1; rs2_addr=31; #1;
    if (rs1_data !== 32'h1234_5678 || rs2_data !== 32'hcafe_babe)
      $fatal(1, "register R/W failed");

    write_reg(5'd0, 32'hffff_ffff);
    rs1_addr=0; #1;
    if (rs1_data !== 32'd0 || dut.regs[0] !== 32'd0)
      $fatal(1, "x0 must remain zero");

    rst=1; @(posedge clk); @(negedge clk); rst=0;
    rs1_addr=1; rs2_addr=31; #1;
    if (rs1_data !== 0 || rs2_data !== 0) $fatal(1, "reset failed");

    $display("[PASS] tb_regfile");
    $finish;
  end
endmodule
