module pwm_peripheral #(
  parameter logic [31:0] DEFAULT_PERIOD = 32'd1000,
  parameter logic [31:0] DEFAULT_DUTY   = 32'd0
) (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        bus_valid_i,
  input  logic        bus_we_i,
  input  logic [11:0] bus_addr_i,
  input  logic [31:0] bus_wdata_i,
  input  logic [3:0]  bus_wstrb_i,
  output logic [31:0] bus_rdata_o,
  output logic        pwm_o
);
  logic enable_q;
  logic [31:0] period_q, duty_q, counter_q;

  function automatic [31:0] merge_wstrb(
    input [31:0] old_v,
    input [31:0] new_v,
    input [3:0]  strobe
  );
    reg [31:0] tmp;
    begin
      tmp = old_v;
      if (strobe[0]) tmp[7:0]   = new_v[7:0];
      if (strobe[1]) tmp[15:8]  = new_v[15:8];
      if (strobe[2]) tmp[23:16] = new_v[23:16];
      if (strobe[3]) tmp[31:24] = new_v[31:24];
      merge_wstrb = tmp;
    end
  endfunction

  always_comb begin
    case (bus_addr_i[5:2])
      4'h0: bus_rdata_o = {31'd0, enable_q};
      4'h1: bus_rdata_o = period_q;
      4'h2: bus_rdata_o = duty_q;
      4'h3: bus_rdata_o = counter_q;
      default: bus_rdata_o = 32'd0;
    endcase
  end

  always_comb begin
    if (!enable_q || (period_q == 32'd0))
      pwm_o = 1'b0;
    else if (duty_q >= period_q)
      pwm_o = 1'b1;
    else
      pwm_o = (counter_q < duty_q);
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      enable_q  <= 1'b0;
      period_q  <= DEFAULT_PERIOD;
      duty_q    <= DEFAULT_DUTY;
      counter_q <= 32'd0;
    end else begin
      if (!enable_q || (period_q == 32'd0))
        counter_q <= 32'd0;
      else if (counter_q >= (period_q - 32'd1))
        counter_q <= 32'd0;
      else
        counter_q <= counter_q + 32'd1;

      if (bus_valid_i && bus_we_i) begin
        case (bus_addr_i[5:2])
          4'h0: if (bus_wstrb_i[0]) enable_q <= bus_wdata_i[0];
          4'h1: period_q <= merge_wstrb(period_q, bus_wdata_i, bus_wstrb_i);
          4'h2: duty_q   <= merge_wstrb(duty_q, bus_wdata_i, bus_wstrb_i);
          default: ;
        endcase
      end
    end
  end
endmodule
