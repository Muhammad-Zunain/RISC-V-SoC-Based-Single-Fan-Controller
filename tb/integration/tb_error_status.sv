`timescale 1ns/1ps
module tb_error_status;
  localparam integer DIV=16;
  logic clk=0,rst=1;
  logic uv,uwe;logic[11:0]ua;logic[31:0]uw,ur;logic[3:0]us;logic utx,urx=1;
  logic sv,swe;logic[11:0]sa;logic[31:0]sw,sr;logic[3:0]ss;logic sclk,mosi,miso,csn;
  logic[7:0]slave_rx;logic slave_valid;logic[31:0]tmp;integer k,timeout;
  always #5 clk=~clk;
  uart_peripheral #(.DEFAULT_BAUD_DIV(DIV)) uart_dut(.clk_i(clk),.rst_i(rst),.bus_valid_i(uv),.bus_we_i(uwe),.bus_addr_i(ua),.bus_wdata_i(uw),.bus_wstrb_i(us),.bus_rdata_o(ur),.uart_tx_o(utx),.uart_rx_i(urx));
  spi_peripheral #(.DEFAULT_CLK_DIV(32'd4)) spi_dut(.clk_i(clk),.rst_i(rst),.bus_valid_i(sv),.bus_we_i(swe),.bus_addr_i(sa),.bus_wdata_i(sw),.bus_wstrb_i(ss),.bus_rdata_o(sr),.spi_sclk_o(sclk),.spi_mosi_o(mosi),.spi_miso_i(miso),.spi_cs_n_o(csn));
  spi_slave_model slave(.rst_i(rst),.cs_n_i(csn),.sclk_i(sclk),.mosi_i(mosi),.miso_o(miso),.last_rx_o(slave_rx),.rx_valid_o(slave_valid));
  task automatic uwr(input[11:0]a,input[31:0]d);begin @(negedge clk);uv=1;uwe=1;ua=a;uw=d;us=4'hf;@(negedge clk);uv=0;uwe=0;end endtask
  task automatic urd(input[11:0]a,output[31:0]d);begin @(negedge clk);uv=1;uwe=0;ua=a;us=0;#1;d=ur;@(negedge clk);uv=0;end endtask
  task automatic swr(input[11:0]a,input[31:0]d);begin @(negedge clk);sv=1;swe=1;sa=a;sw=d;ss=4'hf;@(negedge clk);sv=0;swe=0;end endtask
  task automatic srd(input[11:0]a,output[31:0]d);begin @(negedge clk);sv=1;swe=0;sa=a;ss=0;#1;d=sr;@(negedge clk);sv=0;end endtask
  task automatic bad_uart(input[7:0]d);begin @(negedge clk);urx=0;repeat(DIV)@(posedge clk);for(k=0;k<8;k=k+1)begin @(negedge clk);urx=d[k];repeat(DIV)@(posedge clk);end @(negedge clk);urx=0;repeat(DIV)@(posedge clk);@(negedge clk);urx=1;repeat(DIV*2)@(posedge clk);end endtask
  initial begin
    uv=0;uwe=0;ua=0;uw=0;us=0;sv=0;swe=0;sa=0;sw=0;ss=0;repeat(4)@(posedge clk);@(negedge clk);rst=0;
    fork bad_uart(8'h33); begin timeout=0;tmp=0;while(!tmp[1]&&timeout<500)begin urd(12'h008,tmp);timeout=timeout+1;end end join
    urd(12'h008,tmp);if(!tmp[2])$fatal(1,"UART framing sticky not set %08x",tmp);uwr(12'h008,32'h4);urd(12'h008,tmp);if(tmp[2])$fatal(1,"UART framing W1C failed");
    swr(12'h000,32'ha5);swr(12'h004,1);timeout=0;tmp=0;while(!tmp[0]&&timeout<50)begin srd(12'h008,tmp);timeout=timeout+1;end
    if(timeout>=50)$fatal(1,"SPI did not become busy");swr(12'h004,1);srd(12'h008,tmp);if(!tmp[2])$fatal(1,"SPI start-busy sticky not set");swr(12'h008,4);srd(12'h008,tmp);if(tmp[2])$fatal(1,"SPI error W1C failed");
    $display("[PASS] tb_error_status");$finish;
  end
endmodule
