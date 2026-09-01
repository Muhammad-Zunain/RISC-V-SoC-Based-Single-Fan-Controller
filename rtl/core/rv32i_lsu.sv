module rv32i_lsu (
  input  logic        mem_valid_i,
  input  logic        mem_write_i,
  input  logic [2:0]  funct3_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] rs2_i,
  input  logic [31:0] rdata_i,
  output logic        misaligned_o,
  output logic [31:0] store_wdata_o,
  output logic [3:0]  store_wstrb_o,
  output logic [31:0] load_data_o
);
  always_comb begin
    misaligned_o = 1'b0;
    if (mem_valid_i) begin
      case (funct3_i)
        3'b001, 3'b101: misaligned_o = addr_i[0];       // LH/LHU/SH
        3'b010:         misaligned_o = |addr_i[1:0];    // LW/SW
        default:        misaligned_o = 1'b0;            // byte accesses
      endcase
    end
  end

  always_comb begin
    store_wdata_o = 32'd0;
    store_wstrb_o = 4'b0000;
    if (mem_valid_i && mem_write_i) begin
      case (funct3_i)
        3'b000: begin // SB
          store_wstrb_o = 4'b0001 << addr_i[1:0];
          store_wdata_o = rs2_i << (8 * addr_i[1:0]);
        end
        3'b001: begin // SH
          store_wstrb_o = addr_i[1] ? 4'b1100 : 4'b0011;
          store_wdata_o = rs2_i << (16 * addr_i[1]);
        end
        3'b010: begin // SW
          store_wstrb_o = 4'b1111;
          store_wdata_o = rs2_i;
        end
        default: begin
          store_wstrb_o = 4'b0000;
          store_wdata_o = 32'd0;
        end
      endcase
    end
  end

  always_comb begin
    case (funct3_i)
      3'b000: begin // LB
        case (addr_i[1:0])
          2'd0: load_data_o = {{24{rdata_i[7]}},  rdata_i[7:0]};
          2'd1: load_data_o = {{24{rdata_i[15]}}, rdata_i[15:8]};
          2'd2: load_data_o = {{24{rdata_i[23]}}, rdata_i[23:16]};
          default: load_data_o = {{24{rdata_i[31]}}, rdata_i[31:24]};
        endcase
      end
      3'b001: begin // LH
        if (addr_i[1]) load_data_o = {{16{rdata_i[31]}}, rdata_i[31:16]};
        else           load_data_o = {{16{rdata_i[15]}}, rdata_i[15:0]};
      end
      3'b010: load_data_o = rdata_i; // LW
      3'b100: begin // LBU
        case (addr_i[1:0])
          2'd0: load_data_o = {24'd0, rdata_i[7:0]};
          2'd1: load_data_o = {24'd0, rdata_i[15:8]};
          2'd2: load_data_o = {24'd0, rdata_i[23:16]};
          default: load_data_o = {24'd0, rdata_i[31:24]};
        endcase
      end
      3'b101: begin // LHU
        if (addr_i[1]) load_data_o = {16'd0, rdata_i[31:16]};
        else           load_data_o = {16'd0, rdata_i[15:0]};
      end
      default: load_data_o = 32'd0;
    endcase
  end
endmodule
