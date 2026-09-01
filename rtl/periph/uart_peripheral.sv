module uart_peripheral #(
  parameter logic [31:0] DEFAULT_BAUD_DIV = 32'd434
) (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        bus_valid_i,
  input  logic        bus_we_i,
  input  logic [11:0] bus_addr_i,
  input  logic [31:0] bus_wdata_i,
  input  logic [3:0]  bus_wstrb_i,
  output logic [31:0] bus_rdata_o,
  output logic        uart_tx_o,
  input  logic        uart_rx_i
);
  logic [31:0] baud_div_q;
  logic [7:0]  tx_data_q;
  logic        tx_start_q, tx_busy, tx_done_pulse;
  logic [7:0]  rx_data_wire;
  logic        rx_pulse, rx_frame_pulse;
  logic [7:0]  rx_data_q;
  logic        rx_valid_q, framing_error_q, overrun_q;
  logic        tx_busy_write_error_q, tx_done_q;

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

  uart_tx u_tx (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .baud_div_i(baud_div_q),
    .start_i(tx_start_q),
    .data_i(tx_data_q),
    .tx_o(uart_tx_o),
    .busy_o(tx_busy),
    .done_o(tx_done_pulse)
  );

  uart_rx u_rx (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .baud_div_i(baud_div_q),
    .rx_i(uart_rx_i),
    .data_o(rx_data_wire),
    .valid_o(rx_pulse),
    .framing_error_o(rx_frame_pulse)
  );

  // STATUS bits:
  // [0] TX busy
  // [1] RX valid
  // [2] RX framing error (sticky, W1C)
  // [3] RX overrun (sticky, W1C)
  // [4] TX write attempted while busy (sticky, W1C)
  // [5] TX done (sticky, W1C; cleared by next accepted TX write)
  always_comb begin
    case (bus_addr_i[5:2])
      4'h0: bus_rdata_o = 32'd0; // TXDATA write-only
      4'h1: bus_rdata_o = {24'd0, rx_data_q};
      4'h2: bus_rdata_o = {26'd0, tx_done_q, tx_busy_write_error_q,
                           overrun_q, framing_error_q, rx_valid_q, tx_busy};
      4'h3: bus_rdata_o = baud_div_q;
      default: bus_rdata_o = 32'd0;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      baud_div_q            <= DEFAULT_BAUD_DIV;
      tx_data_q             <= 8'd0;
      tx_start_q            <= 1'b0;
      rx_data_q             <= 8'd0;
      rx_valid_q            <= 1'b0;
      framing_error_q       <= 1'b0;
      overrun_q             <= 1'b0;
      tx_busy_write_error_q <= 1'b0;
      tx_done_q             <= 1'b0;
    end else begin
      tx_start_q <= 1'b0;

      if (tx_done_pulse)
        tx_done_q <= 1'b1;

      // Reading RXDATA consumes the currently latched byte. If a new byte
      // arrives on the same clock, the receive event below wins.
      if (bus_valid_i && !bus_we_i && (bus_addr_i[5:2] == 4'h1))
        rx_valid_q <= 1'b0;

      if (rx_pulse) begin
        if (rx_valid_q && !(bus_valid_i && !bus_we_i && (bus_addr_i[5:2] == 4'h1)))
          overrun_q <= 1'b1;
        rx_data_q  <= rx_data_wire;
        rx_valid_q <= 1'b1;
        if (rx_frame_pulse)
          framing_error_q <= 1'b1;
      end

      if (bus_valid_i && bus_we_i) begin
        case (bus_addr_i[5:2])
          4'h0: begin // TXDATA
            if (bus_wstrb_i[0]) begin
              if (!tx_busy) begin
                tx_data_q  <= bus_wdata_i[7:0];
                tx_start_q <= 1'b1;
                tx_done_q  <= 1'b0;
              end else begin
                tx_busy_write_error_q <= 1'b1;
              end
            end
          end
          4'h2: begin // STATUS W1C sticky bits
            if (bus_wdata_i[2]) framing_error_q       <= 1'b0;
            if (bus_wdata_i[3]) overrun_q             <= 1'b0;
            if (bus_wdata_i[4]) tx_busy_write_error_q <= 1'b0;
            if (bus_wdata_i[5]) tx_done_q             <= 1'b0;
          end
          4'h3: baud_div_q <= merge_wstrb(baud_div_q, bus_wdata_i, bus_wstrb_i);
          default: ;
        endcase
      end
    end
  end
endmodule
