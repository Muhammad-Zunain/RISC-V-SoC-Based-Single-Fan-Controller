module spi_peripheral #(
  parameter logic [31:0] DEFAULT_CLK_DIV = 32'd4
) (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        bus_valid_i,
  input  logic        bus_we_i,
  input  logic [11:0] bus_addr_i,
  input  logic [31:0] bus_wdata_i,
  input  logic [3:0]  bus_wstrb_i,
  output logic [31:0] bus_rdata_o,
  output logic        spi_sclk_o,
  output logic        spi_mosi_o,
  input  logic        spi_miso_i,
  output logic        spi_cs_n_o
);
  logic [7:0] tx_data_q;
  logic [7:0] rx_data_wire, rx_data_q;
  logic [31:0] clk_div_q;
  logic start_q, busy, done_pulse, done_q, start_busy_error_q;

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

  spi_master u_master (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .clk_div_i(clk_div_q),
    .start_i(start_q),
    .tx_data_i(tx_data_q),
    .rx_data_o(rx_data_wire),
    .busy_o(busy),
    .done_o(done_pulse),
    .sclk_o(spi_sclk_o),
    .mosi_o(spi_mosi_o),
    .miso_i(spi_miso_i),
    .cs_n_o(spi_cs_n_o)
  );

  always_comb begin
    case (bus_addr_i[5:2])
      4'h0: bus_rdata_o = {24'd0, tx_data_q};
      4'h1: bus_rdata_o = 32'd0; // CTRL: write bit0=START
      4'h2: bus_rdata_o = {29'd0, start_busy_error_q, done_q, busy};
      4'h3: bus_rdata_o = {24'd0, rx_data_q};
      4'h4: bus_rdata_o = clk_div_q;
      default: bus_rdata_o = 32'd0;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      tx_data_q <= 8'd0;
      rx_data_q <= 8'd0;
      clk_div_q <= DEFAULT_CLK_DIV;
      start_q   <= 1'b0;
      done_q    <= 1'b0;
      start_busy_error_q <= 1'b0;
    end else begin
      start_q <= 1'b0;

      if (done_pulse) begin
        rx_data_q <= rx_data_wire;
        done_q    <= 1'b1;
      end

      if (bus_valid_i && bus_we_i) begin
        case (bus_addr_i[5:2])
          4'h0: if (bus_wstrb_i[0]) tx_data_q <= bus_wdata_i[7:0];
          4'h1: begin
            if (bus_wdata_i[0]) begin
              if (!busy) begin
                start_q <= 1'b1;
                done_q  <= 1'b0;
              end else begin
                start_busy_error_q <= 1'b1;
              end
            end
          end
          4'h2: begin
            if (bus_wdata_i[1]) done_q <= 1'b0;             // W1C done
            if (bus_wdata_i[2]) start_busy_error_q <= 1'b0; // W1C error
          end
          4'h4: clk_div_q <= merge_wstrb(clk_div_q, bus_wdata_i, bus_wstrb_i);
          default: ;
        endcase
      end
    end
  end
endmodule
