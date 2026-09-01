`timescale 1ns/1ps
module tb_uart_peripheral;
  localparam [31:0] DIV=32'd16;
  logic clk=0,rst=1;
  logic bus_valid,bus_we;logic[11:0]bus_addr;logic[31:0]bus_wdata,bus_rdata;logic[3:0]bus_wstrb;logic tx;
  integer timeout;logic[31:0]tmp;
  always #5 clk=~clk;
  uart_peripheral #(.DEFAULT_BAUD_DIV(DIV)) dut(.clk_i(clk),.rst_i(rst),.bus_valid_i(bus_valid),.bus_we_i(bus_we),
    .bus_addr_i(bus_addr),.bus_wdata_i(bus_wdata),.bus_wstrb_i(bus_wstrb),.bus_rdata_o(bus_rdata),.uart_tx_o(tx),.uart_rx_i(tx));

  task automatic wr(input[11:0]a,input[31:0]d);
    begin @(negedge clk);bus_valid=1;bus_we=1;bus_addr=a;bus_wdata=d;bus_wstrb=4'hf;@(negedge clk);bus_valid=0;bus_we=0;end
  endtask
  task automatic rd(input[11:0]a,output[31:0]d);
    begin @(negedge clk);bus_valid=1;bus_we=0;bus_addr=a;bus_wstrb=0;#1;d=bus_rdata;@(negedge clk);bus_valid=0;end
  endtask

  initial begin
    bus_valid=0;bus_we=0;bus_addr=0;bus_wdata=0;bus_wstrb=0;
    repeat(4)@(posedge clk);@(negedge clk);rst=0;
    rd(12'h00c,tmp);if(tmp!=DIV)$fatal(1,"UART baud register reset failed");
    wr(12'h000,32'h000000a5);
    // Attempt a second write while TX is busy; sticky error bit[4] must set.
    repeat(2)@(posedge clk);wr(12'h000,32'h00000055);rd(12'h008,tmp);if(!tmp[4])$fatal(1,"TX busy-write error missing status=%08x",tmp);

    timeout=0;tmp=0;while(!tmp[1]&&timeout<500)begin rd(12'h008,tmp);timeout=timeout+1;end
    if(timeout>=500)$fatal(1,"UART loopback RX timeout");
    if(tmp[2]||tmp[3])$fatal(1,"UART RX errors status=%08x",tmp);
    rd(12'h004,tmp);if(tmp[7:0]!=8'ha5)$fatal(1,"UART loopback mismatch %02x",tmp[7:0]);
    rd(12'h008,tmp);if(!tmp[5])$fatal(1,"TX done sticky bit missing");
    wr(12'h008,32'h00000030);rd(12'h008,tmp);if(tmp[4]||tmp[5])$fatal(1,"UART W1C failed status=%08x",tmp);
    $display("[PASS] tb_uart_peripheral");$finish;
  end
endmodule
