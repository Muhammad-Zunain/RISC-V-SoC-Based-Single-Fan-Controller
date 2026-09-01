module spi_master (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] clk_div_i,
  input  logic        start_i,
  input  logic [7:0]  tx_data_i,
  output logic [7:0]  rx_data_o,
  output logic        busy_o,
  output logic        done_o,
  output logic        sclk_o,
  output logic        mosi_o,
  input  logic        miso_i,
  output logic        cs_n_o
);
  logic [7:0] tx_shift_q, rx_shift_q;
  logic [2:0] bit_idx_q;
  logic [31:0] div_count_q;
  logic [31:0] div_eff;

  always_comb begin
    div_eff = (clk_div_i < 32'd1) ? 32'd1 : clk_div_i;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rx_data_o   <= 8'd0;
      busy_o      <= 1'b0;
      done_o      <= 1'b0;
      sclk_o      <= 1'b0;
      mosi_o      <= 1'b0;
      cs_n_o      <= 1'b1;
      tx_shift_q  <= 8'd0;
      rx_shift_q  <= 8'd0;
      bit_idx_q   <= 3'd0;
      div_count_q <= 32'd0;
    end else begin
      done_o <= 1'b0;

      if (!busy_o) begin
        sclk_o      <= 1'b0;
        cs_n_o      <= 1'b1;
        div_count_q <= 32'd0;
        if (start_i) begin
          busy_o      <= 1'b1;
          cs_n_o      <= 1'b0;
          tx_shift_q  <= tx_data_i;
          rx_shift_q  <= 8'd0;
          bit_idx_q   <= 3'd0;
          mosi_o      <= tx_data_i[7];
        end
      end else begin
        if (div_count_q >= (div_eff - 32'd1)) begin
          div_count_q <= 32'd0;

          if (!sclk_o) begin
            // Mode-0 rising edge: sample MISO.
            sclk_o     <= 1'b1;
            rx_shift_q <= {rx_shift_q[6:0], miso_i};
          end else begin
            // Mode-0 falling edge: update MOSI for next bit.
            sclk_o <= 1'b0;
            if (bit_idx_q == 3'd7) begin
              busy_o    <= 1'b0;
              cs_n_o    <= 1'b1;
              rx_data_o <= rx_shift_q;
              done_o    <= 1'b1;
              mosi_o    <= 1'b0;
            end else begin
              bit_idx_q <= bit_idx_q + 3'd1;
              mosi_o    <= tx_shift_q[6 - bit_idx_q];
            end
          end
        end else begin
          div_count_q <= div_count_q + 32'd1;
        end
      end
    end
  end
endmodule
