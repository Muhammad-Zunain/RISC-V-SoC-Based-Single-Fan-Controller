module uart_tx (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] baud_div_i,
  input  logic        start_i,
  input  logic [7:0]  data_i,
  output logic        tx_o,
  output logic        busy_o,
  output logic        done_o
);
  logic [9:0] frame_q;
  logic [3:0] bit_idx_q;
  logic [31:0] count_q;
  logic [31:0] baud_eff;

  always_comb begin
    baud_eff = (baud_div_i < 32'd2) ? 32'd2 : baud_div_i;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      tx_o      <= 1'b1;
      busy_o    <= 1'b0;
      done_o    <= 1'b0;
      frame_q   <= 10'h3ff;
      bit_idx_q <= 4'd0;
      count_q   <= 32'd0;
    end else begin
      done_o <= 1'b0;

      if (!busy_o) begin
        tx_o    <= 1'b1;
        count_q <= 32'd0;
        if (start_i) begin
          frame_q   <= {1'b1, data_i, 1'b0};
          bit_idx_q <= 4'd0;
          tx_o      <= 1'b0;
          busy_o    <= 1'b1;
        end
      end else begin
        if (count_q >= (baud_eff - 32'd1)) begin
          count_q <= 32'd0;
          if (bit_idx_q == 4'd9) begin
            tx_o   <= 1'b1;
            busy_o <= 1'b0;
            done_o <= 1'b1;
          end else begin
            bit_idx_q <= bit_idx_q + 4'd1;
            tx_o      <= frame_q[bit_idx_q + 4'd1];
          end
        end else begin
          count_q <= count_q + 32'd1;
        end
      end
    end
  end
endmodule
