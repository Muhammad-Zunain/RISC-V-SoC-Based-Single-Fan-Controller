`timescale 1ns/1ps
module tb_instruction_sram;
  logic [31:0] addr,rdata; logic fault;
  instruction_sram #(.WORDS(8),.INIT_FILE("firmware/test_imem.hex")) dut(.addr_i(addr),.rdata_o(rdata),.fault_o(fault));
  initial begin
    addr=0;#1;if(fault||rdata!==32'h12345678)$fatal(1,"IMEM word0 failed %08x",rdata);
    addr=4;#1;if(fault||rdata!==32'hdeadbeef)$fatal(1,"IMEM word1 failed %08x",rdata);
    addr=8;#1;if(fault||rdata!==32'h00000013)$fatal(1,"IMEM word2 failed %08x",rdata);
    addr=2;#1;if(!fault)$fatal(1,"IMEM misalignment fault missing");
    addr=32;#1;if(!fault)$fatal(1,"IMEM range fault missing");
    $display("[PASS] tb_instruction_sram");$finish;
  end
endmodule
