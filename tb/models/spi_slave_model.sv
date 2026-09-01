module spi_slave_model #(
  parameter logic [7:0] RESPONSE = 8'h3c
) (
  input  logic       rst_i,
  input  logic       cs_n_i,
  input  logic       sclk_i,
  input  logic       mosi_i,
  output logic       miso_o,
  output logic [7:0] last_rx_o,
  output logic       rx_valid_o
);
  logic [7:0] rx_shift_q;
  logic [2:0] bit_idx_q;

  // Mode-0 slave model: present data before the master's rising sample edge.
  always_comb begin
    miso_o = cs_n_i ? 1'b0 : RESPONSE[7 - bit_idx_q];
  end

  // Advance response bit on each falling edge; reset index after chip-select release.
  always @(negedge sclk_i or posedge cs_n_i or posedge rst_i) begin
    if (rst_i || cs_n_i)
      bit_idx_q <= 3'd0;
    else if (bit_idx_q != 3'd7)
      bit_idx_q <= bit_idx_q + 3'd1;
  end

  // Capture MOSI on rising edges. rx_valid_o is sticky for this simple TB model.
  always @(posedge sclk_i or posedge rst_i) begin
    if (rst_i) begin
      rx_shift_q <= 8'd0;
      last_rx_o  <= 8'd0;
      rx_valid_o <= 1'b0;
    end else if (!cs_n_i) begin
      rx_shift_q <= {rx_shift_q[6:0], mosi_i};
      if (bit_idx_q == 3'd7) begin
        last_rx_o  <= {rx_shift_q[6:0], mosi_i};
        rx_valid_o <= 1'b1;
      end
    end
  end
endmodule
