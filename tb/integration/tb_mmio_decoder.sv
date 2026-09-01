`timescale 1ns/1ps
module tb_mmio_decoder;
  import soc_pkg::*;
  logic valid; logic [31:0] addr;
  logic sd,sc,sp,su,ss,fault;
  mmio_decoder #(.DMEM_WORDS(16),.CFG_WORDS(8)) dut(
    .valid_i(valid),.addr_i(addr),.sel_dmem_o(sd),.sel_cfg_o(sc),.sel_pwm_o(sp),.sel_uart_o(su),.sel_spi_o(ss),.fault_o(fault));

  task automatic chk(input [31:0] a,input [4:0] sels,input logic f,input string n);
    begin addr=a; valid=1;#1;if({ss,su,sp,sc,sd}!==sels||fault!==f)$fatal(1,"%s decode failed addr=%08x sel=%b fault=%b",n,a,{ss,su,sp,sc,sd},fault);end
  endtask
  initial begin
    valid=0;addr=0;#1;if(sd||sc||sp||su||ss||fault)$fatal(1,"invalid cycle selected target");
    chk(DMEM_BASE,5'b00001,0,"DMEM base");
    chk(DMEM_BASE+60,5'b00001,0,"DMEM last word");
    chk(CFG_BASE,5'b00010,0,"CFG base");
    chk(PWM_BASE+12'h0fc,5'b00100,0,"PWM page");
    chk(UART_BASE+12'h008,5'b01000,0,"UART page");
    chk(SPI_BASE+12'h010,5'b10000,0,"SPI page");
    chk(32'h3000_0000,5'b00000,1,"unmapped");
    $display("[PASS] tb_mmio_decoder");$finish;
  end
endmodule
