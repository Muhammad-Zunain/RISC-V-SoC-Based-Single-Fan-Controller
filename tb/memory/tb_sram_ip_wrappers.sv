`timescale 1ns/1ps
module tb_sram_ip_wrappers;
  logic clk=0, rst=1;
  logic ireq, iready, ifault; logic[31:0] ia, ir;
  logic dreq,dwe,dready,dfault; logic[31:0] da,dwd,drd; logic[3:0] dstrb;
  logic creq,cwe,cready,cfault; logic[31:0] ca,cwd,crd; logic[3:0] cstrb;
  integer before_cycle, cycle_count;

  always #5 clk=~clk;
  always @(posedge clk) cycle_count <= cycle_count + 1;

  imem_ip_wrapper #(.WORDS(256)) u_i(
    .clk_i(clk),.rst_i(rst),.req_i(ireq),.addr_i(ia),.ready_o(iready),.rdata_o(ir),.fault_o(ifault));
  dmem_ip_wrapper #(.WORDS(256)) u_d(
    .clk_i(clk),.rst_i(rst),.req_i(dreq),.write_i(dwe),.addr_i(da),.wdata_i(dwd),.wstrb_i(dstrb),.ready_o(dready),.rdata_o(drd),.fault_o(dfault));
  config_ip_wrapper #(.WORDS(256)) u_c(
    .clk_i(clk),.rst_i(rst),.req_i(creq),.write_i(cwe),.addr_i(ca),.wdata_i(cwd),.wstrb_i(cstrb),.ready_o(cready),.rdata_o(crd),.fault_o(cfault));

  task automatic imem_read(input [31:0] a, input [31:0] exp);
    begin
      @(negedge clk); ia=a; ireq=1; before_cycle=cycle_count;
      @(posedge clk); @(negedge clk); ireq=0;
      while(!iready) @(negedge clk);
      if(cycle_count-before_cycle != 1) $fatal(1,"IMEM ready latency expected 1, got %0d",cycle_count-before_cycle);
      if(ifault) $fatal(1,"IMEM unexpected fault addr=%08x",a);
      if(ir!==exp) $fatal(1,"IMEM data addr=%08x got=%08x exp=%08x",a,ir,exp);
    end
  endtask

  task automatic dmem_write(input [31:0] a,input[31:0] d,input[3:0] s);
    begin
      @(negedge clk); da=a;dwd=d;dstrb=s;dwe=1;dreq=1;
      @(posedge clk);@(negedge clk);dreq=0;dwe=0;
      while(!dready)@(negedge clk);
      if(dfault)$fatal(1,"DMEM write fault");
    end
  endtask

  task automatic dmem_read(input [31:0] a,input[31:0] exp);
    begin
      @(negedge clk);da=a;dwe=0;dstrb=0;dreq=1;
      @(posedge clk);@(negedge clk);dreq=0;
      while(!dready)@(negedge clk);
      if(dfault||drd!==exp)$fatal(1,"DMEM read got=%08x exp=%08x",drd,exp);
    end
  endtask

  task automatic cfg_read(input [31:0] a,input[31:0] exp);
    begin
      @(negedge clk);ca=a;cwe=0;cstrb=0;creq=1;
      @(posedge clk);@(negedge clk);creq=0;
      while(!cready)@(negedge clk);
      if(cfault||crd!==exp)$fatal(1,"CFG read got=%08x exp=%08x",crd,exp);
    end
  endtask

  initial begin
    cycle_count=0;
    ireq=0;ia=0;
    dreq=0;dwe=0;da=32'h10000000;dwd=0;dstrb=0;
    creq=0;cwe=0;ca=32'h20000000;cwd=0;cstrb=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;

    imem_read(32'h00000000,32'h20000537);
    cfg_read(32'h20000000,32'd100);
    cfg_read(32'h20000004,32'd30);
    cfg_read(32'h20000008,32'h48);
    cfg_read(32'h2000000c,32'ha5);

    dmem_write(32'h10000004,32'hdeadbeef,4'hf);
    dmem_read (32'h10000004,32'hdeadbeef);
    dmem_write(32'h10000004,32'h0000aa00,4'h2);
    dmem_read (32'h10000004,32'hdeadaaef);

    $display("[PASS] tb_sram_ip_wrappers");
    $finish;
  end
endmodule
