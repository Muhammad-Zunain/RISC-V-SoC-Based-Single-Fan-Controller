`timescale 1ns/1ps
module tb_spi_master;
  logic clk=0,rst=1,start;logic[7:0]txdata,rxdata;logic busy,done,sclk,mosi,miso,csn;
  logic[7:0]slave_rx;logic slave_valid;integer timeout;
  always #5 clk=~clk;
  spi_master dut(.clk_i(clk),.rst_i(rst),.clk_div_i(32'd2),.start_i(start),.tx_data_i(txdata),.rx_data_o(rxdata),
    .busy_o(busy),.done_o(done),.sclk_o(sclk),.mosi_o(mosi),.miso_i(miso),.cs_n_o(csn));
  spi_slave_model #(.RESPONSE(8'h3c)) slave(.rst_i(rst),.cs_n_i(csn),.sclk_i(sclk),.mosi_i(mosi),.miso_o(miso),.last_rx_o(slave_rx),.rx_valid_o(slave_valid));
  initial begin
    start=0;txdata=0;repeat(3)@(posedge clk);@(negedge clk);rst=0;
    if(sclk!==0||csn!==1)$fatal(1,"SPI idle state incorrect");
    @(negedge clk);txdata=8'ha5;start=1;@(negedge clk);start=0;
    timeout=0;while(!done&&timeout<200)begin @(posedge clk);timeout=timeout+1;end
    if(timeout>=200)$fatal(1,"SPI master timeout");
    #1;if(rxdata!==8'h3c)$fatal(1,"SPI master RX got=%02x",rxdata);
    if(!slave_valid||slave_rx!==8'ha5)$fatal(1,"SPI slave RX got=%02x",slave_rx);
    @(posedge clk);#1;if(done)$fatal(1,"SPI done should be one-cycle pulse");
    if(busy||!csn||sclk)$fatal(1,"SPI did not return to idle");
    $display("[PASS] tb_spi_master");$finish;
  end
endmodule
