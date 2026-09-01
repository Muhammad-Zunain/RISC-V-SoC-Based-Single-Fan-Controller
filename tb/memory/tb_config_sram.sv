`timescale 1ns/1ps
module tb_config_sram;
  logic clk=0,we; logic [31:0] addr,wdata,rdata; logic [3:0] wstrb;
  always #5 clk=~clk;
  config_sram #(.WORDS(8),.INIT_FILE("firmware/test_config.hex")) dut(.clk_i(clk),.we_i(we),.addr_i(addr),.wdata_i(wdata),.wstrb_i(wstrb),.rdata_o(rdata));
  task automatic wr(input [31:0] a,input [31:0] d,input [3:0] s);
    begin @(negedge clk);addr=a;wdata=d;wstrb=s;we=1;@(negedge clk);we=0;#1;end
  endtask
  initial begin
    we=0;wdata=0;wstrb=0;
    addr=0;#1;if(rdata!==32'd100)$fatal(1,"CFG period preload failed");
    addr=4;#1;if(rdata!==32'd30)$fatal(1,"CFG duty preload failed");
    addr=8;#1;if(rdata!==32'h48)$fatal(1,"CFG UART preload failed");
    addr=12;#1;if(rdata!==32'ha5)$fatal(1,"CFG SPI preload failed");
    wr(4,32'd55,4'hf);if(rdata!==32'd55)$fatal(1,"CFG write failed");
    $display("[PASS] tb_config_sram");$finish;
  end
endmodule
