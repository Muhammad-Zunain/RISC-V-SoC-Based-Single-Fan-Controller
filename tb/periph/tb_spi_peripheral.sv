`timescale 1ns/1ps
module tb_spi_peripheral;
  logic clk=0,rst=1,bus_valid,bus_we;logic[11:0]bus_addr;logic[31:0]bus_wdata,bus_rdata;logic[3:0]bus_wstrb;
  logic sclk,mosi,miso,csn;logic[7:0]slave_rx;logic slave_valid;logic[31:0]tmp;integer timeout;
  always #5 clk=~clk;
  spi_peripheral #(.DEFAULT_CLK_DIV(32'd2)) dut(.clk_i(clk),.rst_i(rst),.bus_valid_i(bus_valid),.bus_we_i(bus_we),
    .bus_addr_i(bus_addr),.bus_wdata_i(bus_wdata),.bus_wstrb_i(bus_wstrb),.bus_rdata_o(bus_rdata),
    .spi_sclk_o(sclk),.spi_mosi_o(mosi),.spi_miso_i(miso),.spi_cs_n_o(csn));
  spi_slave_model #(.RESPONSE(8'h3c)) slave(.rst_i(rst),.cs_n_i(csn),.sclk_i(sclk),.mosi_i(mosi),.miso_o(miso),.last_rx_o(slave_rx),.rx_valid_o(slave_valid));
  task automatic wr(input[11:0]a,input[31:0]d);begin @(negedge clk);bus_valid=1;bus_we=1;bus_addr=a;bus_wdata=d;bus_wstrb=4'hf;@(negedge clk);bus_valid=0;bus_we=0;end endtask
  task automatic rd(input[11:0]a,output[31:0]d);begin @(negedge clk);bus_valid=1;bus_we=0;bus_addr=a;bus_wstrb=0;#1;d=bus_rdata;@(negedge clk);bus_valid=0;end endtask
  initial begin
    bus_valid=0;bus_we=0;bus_addr=0;bus_wdata=0;bus_wstrb=0;repeat(3)@(posedge clk);@(negedge clk);rst=0;
    rd(12'h010,tmp);if(tmp!=2)$fatal(1,"SPI clkdiv reset failed");
    wr(12'h000,32'ha5);wr(12'h004,32'h1);
    timeout=0;tmp=0;while(!tmp[0]&&timeout<50)begin rd(12'h008,tmp);timeout=timeout+1;end
    if(timeout>=50)$fatal(1,"SPI never busy");
    wr(12'h004,32'h1);rd(12'h008,tmp);if(!tmp[2])$fatal(1,"start-busy error missing");
    timeout=0;while(!tmp[1]&&timeout<200)begin rd(12'h008,tmp);timeout=timeout+1;end
    if(timeout>=200)$fatal(1,"SPI done timeout");
    rd(12'h00c,tmp);if(tmp[7:0]!=8'h3c)$fatal(1,"SPI RX mismatch");
    if(!slave_valid||slave_rx!=8'ha5)$fatal(1,"SPI TX mismatch");
    wr(12'h008,32'h6);rd(12'h008,tmp);if(tmp[2]||tmp[1])$fatal(1,"SPI W1C failed status=%08x",tmp);
    $display("[PASS] tb_spi_peripheral");$finish;
  end
endmodule
