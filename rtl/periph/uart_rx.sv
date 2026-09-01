module uart_rx (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] baud_div_i,
  input  logic        rx_i,
  output logic [7:0]  data_o,
  output logic        valid_o,
  output logic        framing_error_o
);
  localparam logic [1:0] ST_IDLE  = 2'd0;
  localparam logic [1:0] ST_START = 2'd1;
  localparam logic [1:0] ST_DATA  = 2'd2;
  localparam logic [1:0] ST_STOP  = 2'd3;

  logic rx_meta_q, rx_sync_q;
  logic [1:0] state_q;
  logic [31:0] count_q;
  logic [2:0] bit_idx_q;
  logic [7:0] shift_q;
  logic [31:0] baud_eff;
  logic [31:0] half_div;

  always_comb begin
    baud_eff = (baud_div_i < 32'd4) ? 32'd4 : baud_div_i;
    half_div = baud_eff >> 1;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rx_meta_q <= 1'b1;
      rx_sync_q <= 1'b1;
    end else begin
      rx_meta_q <= rx_i;
      rx_sync_q <= rx_meta_q;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state_q         <= ST_IDLE;
      count_q         <= 32'd0;
      bit_idx_q       <= 3'd0;
      shift_q         <= 8'd0;
      data_o          <= 8'd0;
      valid_o         <= 1'b0;
      framing_error_o <= 1'b0;
    end else begin
      valid_o         <= 1'b0;
      framing_error_o <= 1'b0;

      case (state_q)
        ST_IDLE: begin
          count_q <= 32'd0;
          if (!rx_sync_q) begin
            state_q <= ST_START;
            count_q <= 32'd0;
          end
        end

        ST_START: begin
          if (count_q >= (half_div - 32'd1)) begin
            count_q <= 32'd0;
            if (!rx_sync_q) begin
              bit_idx_q <= 3'd0;
              state_q   <= ST_DATA;
            end else begin
              state_q <= ST_IDLE;
            end
          end else begin
            count_q <= count_q + 32'd1;
          end
        end

        ST_DATA: begin
          if (count_q >= (baud_eff - 32'd1)) begin
            count_q <= 32'd0;
            shift_q[bit_idx_q] <= rx_sync_q;
            if (bit_idx_q == 3'd7) begin
              state_q <= ST_STOP;
            end else begin
              bit_idx_q <= bit_idx_q + 3'd1;
            end
          end else begin
            count_q <= count_q + 32'd1;
          end
        end

        ST_STOP: begin
          if (count_q >= (baud_eff - 32'd1)) begin
            count_q <= 32'd0;
            data_o  <= shift_q;
            valid_o <= 1'b1;
            if (!rx_sync_q)
              framing_error_o <= 1'b1;
            state_q <= ST_IDLE;
          end else begin
            count_q <= count_q + 32'd1;
          end
        end

        default: state_q <= ST_IDLE;
      endcase
    end
  end
endmodule
