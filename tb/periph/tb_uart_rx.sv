`timescale 1ns/1ps
module tb_uart_rx;
  localparam integer DIV=16;
  logic clk=0,rst=1,rx=1;logic[7:0]data;logic valid,frame_err;
  integer k,timeout;
  always #5 clk=~clk;
  uart_rx dut(.clk_i(clk),.rst_i(rst),.baud_div_i(DIV),.rx_i(rx),.data_o(data),.valid_o(valid),.framing_error_o(frame_err));

  task automatic bit_hold(input logic v,input integer n);
    begin @(negedge clk);rx=v;repeat(n)@(posedge clk);end
  endtask
  task automatic send_frame(input [7:0] d,input logic good_stop);
    begin
      bit_hold(0,DIV);
      for(k=0;k<8;k=k+1)bit_hold(d[k],DIV);
      bit_hold(good_stop,DIV);
      bit_hold(1,DIV*2);
    end
  endtask
  task automatic expect_byte(input [7:0] exp,input logic exp_err);
    begin timeout=0;while(!valid&&timeout<400)begin @(posedge clk);timeout=timeout+1;end
      if(timeout>=400)$fatal(1,"UART RX timeout");
      if(data!==exp||frame_err!==exp_err)$fatal(1,"UART RX got=%02x err=%b exp=%02x err=%b",data,frame_err,exp,exp_err);
    end
  endtask

  initial begin
    repeat(4)@(posedge clk);@(negedge clk);rst=0;
    fork send_frame(8'h5a,1'b1); expect_byte(8'h5a,1'b0); join
    repeat(DIV)@(posedge clk);
    fork send_frame(8'hc3,1'b0); expect_byte(8'hc3,1'b1); join
    repeat(DIV)@(posedge clk);
    // False start shorter than half a bit must not produce a byte.
    bit_hold(0,2);bit_hold(1,DIV*2);if(valid)$fatal(1,"false start produced valid byte");
    $display("[PASS] tb_uart_rx");$finish;
  end
endmodule
