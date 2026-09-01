module rv32i_alu (
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  logic [3:0]  op_i,
  output logic [31:0] y_o
);
  import soc_pkg::*;

  always_comb begin
    case (op_i)
      ALU_ADD:  y_o = a_i + b_i;
      ALU_SUB:  y_o = a_i - b_i;
      ALU_SLL:  y_o = a_i << b_i[4:0];
      ALU_SLT:  y_o = ($signed(a_i) < $signed(b_i)) ? 32'd1 : 32'd0;
      ALU_SLTU: y_o = (a_i < b_i) ? 32'd1 : 32'd0;
      ALU_XOR:  y_o = a_i ^ b_i;
      ALU_SRL:  y_o = a_i >> b_i[4:0];
      ALU_SRA:  y_o = $signed(a_i) >>> b_i[4:0];
      ALU_OR:   y_o = a_i | b_i;
      ALU_AND:  y_o = a_i & b_i;
      default:  y_o = 32'd0;
    endcase
  end
endmodule
