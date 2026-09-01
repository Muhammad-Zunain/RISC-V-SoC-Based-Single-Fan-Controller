`timescale 1ns/1ps
module tb_lsu;
  logic valid,write;
  logic [2:0] funct3;
  logic [31:0] addr,rs2,rdata;
  logic misaligned;
  logic [31:0] swdata,ldata;
  logic [3:0] wstrb;

  rv32i_lsu dut(.mem_valid_i(valid),.mem_write_i(write),.funct3_i(funct3),.addr_i(addr),
    .rs2_i(rs2),.rdata_i(rdata),.misaligned_o(misaligned),.store_wdata_o(swdata),
    .store_wstrb_o(wstrb),.load_data_o(ldata));

  initial begin
    valid=1; write=1; rs2=32'h1122_3344; rdata=32'h80ff_7f01;

    funct3=3'b000; addr=3; #1;
    if(misaligned || wstrb!==4'b1000 || swdata!==32'h4400_0000)$fatal(1,"SB lane failed");

    funct3=3'b001; addr=2; #1;
    if(misaligned || wstrb!==4'b1100 || swdata!==32'h3344_0000)$fatal(1,"SH lane failed");
    addr=1; #1; if(!misaligned)$fatal(1,"misaligned SH not detected");

    funct3=3'b010; addr=0; #1;
    if(misaligned || wstrb!==4'hf || swdata!==32'h1122_3344)$fatal(1,"SW failed");
    addr=2; #1; if(!misaligned)$fatal(1,"misaligned SW not detected");

    write=0;
    funct3=3'b000; addr=3; #1; if(ldata!==32'hffff_ff80)$fatal(1,"LB sign extend failed %08x",ldata);
    funct3=3'b100; addr=1; #1; if(ldata!==32'h0000_007f)$fatal(1,"LBU failed %08x",ldata);
    funct3=3'b001; addr=2; #1; if(ldata!==32'hffff_80ff)$fatal(1,"LH failed %08x",ldata);
    funct3=3'b101; addr=2; #1; if(ldata!==32'h0000_80ff)$fatal(1,"LHU failed %08x",ldata);
    funct3=3'b010; addr=0; #1; if(ldata!==rdata)$fatal(1,"LW failed");

    $display("[PASS] tb_lsu"); $finish;
  end
endmodule
