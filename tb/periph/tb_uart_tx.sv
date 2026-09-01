`timescale 1ns/1ps
module tb_uart_tx;
  localparam [31:0] DIV=32'd16;
  logic clk=0,rst=1,start;logic[7:0]data;logic tx,busy,done;
  logic [7:0] observed;logic valid,frame_err;
  integer timeout;
  always #5 clk=~clk;

  uart_tx dut(.clk_i(clk),.rst_i(rst),.baud_div_i(DIV),.start_i(start),.data_i(data),.tx_o(tx),.busy_o(busy),.done_o(done));
  uart_terminal_model #(.BAUD_DIV(DIV)) monitor(.clk_i(clk),.rst_i(rst),.serial_i(tx),.last_byte_o(observed),.byte_valid_o(valid),.framing_error_o(frame_err));

  task automatic send(input [7:0] d);
    begin @(negedge clk);data=d;start=1;@(negedge clk);start=0;end
  endtask
  task automatic wait_byte(input [7:0] exp);
    begin timeout=0;while(!valid&&timeout<400)begin @(posedge clk);timeout=timeout+1;end
      if(timeout>=400)$fatal(1,"UART TX monitor timeout");
      if(frame_err||observed!==exp)$fatal(1,"UART TX mismatch got=%02x exp=%02x frame=%b",observed,exp,frame_err);
      timeout=0;while(!done&&timeout<100)begin @(posedge clk);timeout=timeout+1;end
      if(timeout>=100)$fatal(1,"UART TX done missing");
    end
  endtask

  initial begin
    start=0;data=0;repeat(4)@(posedge clk);@(negedge clk);rst=0;
    if(tx!==1||busy!==0)$fatal(1,"UART idle state failed");
    send(8'h55);#1;if(!busy)$fatal(1,"busy did not assert");wait_byte(8'h55);
    repeat(4)@(posedge clk);send(8'ha5);wait_byte(8'ha5);
    repeat(4)@(posedge clk);send(8'h48);wait_byte(8'h48);
    $display("[PASS] tb_uart_tx");$finish;
  end
endmodule
