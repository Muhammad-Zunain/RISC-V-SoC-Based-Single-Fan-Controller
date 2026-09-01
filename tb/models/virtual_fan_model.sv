module virtual_fan_model #(
  parameter integer WINDOW_CYCLES = 64
) (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        pwm_i,
  output logic [31:0] duty_permille_o,
  output logic        sample_valid_o
);
  integer total_q;
  integer high_q;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      total_q          <= 0;
      high_q           <= 0;
      duty_permille_o  <= 32'd0;
      sample_valid_o   <= 1'b0;
    end else begin
      sample_valid_o <= 1'b0;
      if (total_q == WINDOW_CYCLES - 1) begin
        duty_permille_o <= ((high_q + (pwm_i ? 1 : 0)) * 1000) / WINDOW_CYCLES;
        sample_valid_o  <= 1'b1;
        total_q         <= 0;
        high_q          <= 0;
      end else begin
        total_q <= total_q + 1;
        if (pwm_i)
          high_q <= high_q + 1;
      end
    end
  end
endmodule
