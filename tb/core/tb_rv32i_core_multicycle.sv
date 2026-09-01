`timescale 1ns/1ps
module tb_rv32i_core_multicycle;
  logic clk=0, rst=1;
  logic ireq, iready, ifault;
  logic [31:0] ia, ir;
  logic dreq, dw, dready, dfault;
  logic [31:0] da, dwd, drd;
  logic [3:0] dstrb;
  logic [31:0] pc, ins, cause;
  logic halted, trap;
  logic [3:0] state;
  logic [31:0] imem[0:127];
  logic [31:0] dmem[0:31];
  integer i, timeout;
  `include "tb/common/rv32i_encode.svh"

  always #5 clk=~clk;

  rv32i_core dut (
    .clk_i(clk), .rst_i(rst),
    .imem_req_o(ireq), .imem_addr_o(ia), .imem_ready_i(iready),
    .imem_rdata_i(ir), .imem_fault_i(ifault),
    .dmem_req_o(dreq), .dmem_write_o(dw), .dmem_addr_o(da),
    .dmem_wdata_o(dwd), .dmem_wstrb_o(dstrb), .dmem_ready_i(dready),
    .dmem_rdata_i(drd), .dmem_fault_i(dfault),
    .pc_o(pc), .instr_o(ins), .halted_o(halted), .trap_o(trap),
    .trap_cause_o(cause), .state_o(state)
  );

  // One-cycle synchronous instruction-memory response model.
  always @(posedge clk) begin
    if (rst) begin
      iready <= 1'b0;
      ifault <= 1'b0;
      ir     <= 32'h00000013;
    end else begin
      iready <= ireq;
      if (ireq) begin
        ifault <= (ia[1:0] != 0) || (ia[31:2] >= 128);
        if ((ia[1:0] == 0) && (ia[31:2] < 128))
          ir <= imem[ia[31:2]];
        else
          ir <= 32'h00000013;
      end
    end
  end

  // One-cycle synchronous data-memory response model.
  always @(posedge clk) begin
    if (rst) begin
      dready <= 1'b0;
      dfault <= 1'b0;
      drd    <= 32'd0;
    end else begin
      dready <= dreq;
      if (dreq) begin
        dfault <= (da[31:2] >= 32);
        if (da[31:2] < 32) begin
          drd <= dmem[da[31:2]];
          if (dw) begin
            if(dstrb[0]) dmem[da[31:2]][7:0]   <= dwd[7:0];
            if(dstrb[1]) dmem[da[31:2]][15:8]  <= dwd[15:8];
            if(dstrb[2]) dmem[da[31:2]][23:16] <= dwd[23:16];
            if(dstrb[3]) dmem[da[31:2]][31:24] <= dwd[31:24];
          end
        end else begin
          drd <= 32'd0;
        end
      end
    end
  end

  initial begin
    iready=0; ifault=0; ir=32'h00000013;
    dready=0; dfault=0; drd=0;
    for(i=0;i<128;i=i+1) imem[i]=32'h00000013;
    for(i=0;i<32;i=i+1) dmem[i]=0;

    imem[0] = enc_i(5,0,3'b000,1,7'b0010011);             // addi x1,x0,5
    imem[1] = enc_i(7,0,3'b000,2,7'b0010011);             // addi x2,x0,7
    imem[2] = enc_r(7'b0000000,2,1,3'b000,3,7'b0110011);  // add x3,x1,x2=12
    imem[3] = enc_s(0,3,0,3'b010);                        // sw x3,0(x0)
    imem[4] = enc_i(0,0,3'b010,4,7'b0000011);             // lw x4,0(x0)=12
    imem[5] = enc_b(8,4,3,3'b000);                        // beq x3,x4,+8
    imem[6] = enc_i(99,0,3'b000,5,7'b0010011);            // skipped
    imem[7] = enc_i(1,0,3'b000,5,7'b0010011);             // x5=1
    imem[8] = 32'h00100073;                               // ebreak

    repeat(4) @(posedge clk);
    @(negedge clk); rst=0;

    timeout=0;
    while(!halted && timeout<500) begin
      @(posedge clk); timeout=timeout+1;
    end

    if(timeout>=500) $fatal(1,"Multicycle core timeout pc=%08x state=%0d",pc,state);
    if(!trap || cause!=32'd3) $fatal(1,"Expected EBREAK cause3, got %0d",cause);
    if(dut.u_regfile.regs[1]!==5) $fatal(1,"ADDI x1 failed");
    if(dut.u_regfile.regs[2]!==7) $fatal(1,"ADDI x2 failed");
    if(dut.u_regfile.regs[3]!==12) $fatal(1,"ADD failed");
    if(dut.u_regfile.regs[4]!==12) $fatal(1,"LW failed");
    if(dut.u_regfile.regs[5]!==1) $fatal(1,"Branch failed");
    if(dmem[0]!==12) $fatal(1,"SW failed dmem0=%08x",dmem[0]);
    if(dut.u_regfile.regs[0]!==0) $fatal(1,"x0 corrupted");

    $display("[PASS] tb_rv32i_core_multicycle");
    $finish;
  end
endmodule
