`timescale 1ns/1ps
module tb_pwm;
  logic clk=0,rst=1;
  logic bus_valid,bus_we; logic [11:0] bus_addr; logic [31:0] bus_wdata,bus_rdata; logic [3:0] bus_wstrb;
  logic pwm;
  integer i,highs;
  always #5 clk=~clk;

  pwm_peripheral #(.DEFAULT_PERIOD(32'd100),.DEFAULT_DUTY(32'd0)) dut(
    .clk_i(clk),.rst_i(rst),.bus_valid_i(bus_valid),.bus_we_i(bus_we),.bus_addr_i(bus_addr),
    .bus_wdata_i(bus_wdata),.bus_wstrb_i(bus_wstrb),.bus_rdata_o(bus_rdata),.pwm_o(pwm));

  task automatic wr(input [11:0] a,input [31:0] d,input [3:0] s);
    begin @(negedge clk);bus_valid=1;bus_we=1;bus_addr=a;bus_wdata=d;bus_wstrb=s;@(negedge clk);bus_valid=0;bus_we=0;end
  endtask
  task automatic rd(input [11:0] a,output [31:0] d);
    begin bus_addr=a;bus_valid=1;bus_we=0;#1;d=bus_rdata;bus_valid=0;end
  endtask
  task automatic count_high(input integer n,output integer h);
    begin h=0;for(i=0;i<n;i=i+1)begin @(negedge clk);if(pwm)h=h+1;end end
  endtask
  logic [31:0] tmp;
  initial begin
    bus_valid=0;bus_we=0;bus_addr=0;bus_wdata=0;bus_wstrb=0;
    repeat(3)@(posedge clk);@(negedge clk);rst=0;
    rd(12'h004,tmp);if(tmp!=100)$fatal(1,"default period failed");

    // Capstone nominal test: period=100 clocks, duty=30 clocks.
    wr(12'h004,32'd100,4'hf);wr(12'h008,32'd30,4'hf);wr(12'h000,32'd1,4'h1);
    count_high(500,highs);if(highs!=150)$fatal(1,"30%% PWM failed highs=%0d",highs);

    wr(12'h008,32'd0,4'hf);count_high(200,highs);if(highs!=0)$fatal(1,"0%% PWM failed");
    wr(12'h008,32'd100,4'hf);count_high(200,highs);if(highs!=200)$fatal(1,"100%% PWM failed highs=%0d",highs);
    wr(12'h000,32'd0,4'h1);count_high(50,highs);if(highs!=0)$fatal(1,"PWM disable failed");

    // Byte strobe test on duty register: only low byte changes.
    wr(12'h008,32'h0000001e,4'b0001);rd(12'h008,tmp);if(tmp[7:0]!=8'h1e)$fatal(1,"PWM byte strobe failed");
    $display("[PASS] tb_pwm");$finish;
  end
endmodule
