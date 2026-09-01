module uart_terminal_model #(
  parameter logic [31:0] BAUD_DIV = 32'd8
) (
  input  logic       clk_i,
  input  logic       rst_i,
  input  logic       serial_i,
  output logic [7:0] last_byte_o,
  output logic       byte_valid_o,
  output logic       framing_error_o
);
  uart_rx u_rx (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .baud_div_i(BAUD_DIV),
    .rx_i(serial_i),
    .data_o(last_byte_o),
    .valid_o(byte_valid_o),
    .framing_error_o(framing_error_o)
  );
endmodule
