`timescale 1ns/1ps
module tb_data_sram;
  logic clk=0,we; logic [31:0] addr,wdata,rdata; logic [3:0] wstrb;
  always #5 clk=~clk;
  data_sram #(.WORDS(8)) dut(.clk_i(clk),.we_i(we),.addr_i(addr),.wdata_i(wdata),.wstrb_i(wstrb),.rdata_o(rdata));
  task automatic wr(input [31:0] a,input [31:0] d,input [3:0] s);
    begin @(negedge clk);addr=a;wdata=d;wstrb=s;we=1;@(negedge clk);we=0;#1;end
  endtask
  initial begin
    we=0;addr=0;wdata=0;wstrb=0;#1;if(rdata!==0)$fatal(1,"DMEM initial zero failed");
    wr(4,32'hdeadbeef,4'hf); if(rdata!==32'hdeadbeef)$fatal(1,"word write failed %08x",rdata);
    wr(4,32'h0000aa00,4'b0010); if(rdata!==32'hdeadaaef)$fatal(1,"byte strobe failed %08x",rdata);
    wr(4,32'h12340000,4'b1100); if(rdata!==32'h1234aaef)$fatal(1,"half strobe failed %08x",rdata);
    addr=32;#1;if(rdata!==0)$fatal(1,"out of range read should be zero");
    $display("[PASS] tb_data_sram");$finish;
  end
endmodule
