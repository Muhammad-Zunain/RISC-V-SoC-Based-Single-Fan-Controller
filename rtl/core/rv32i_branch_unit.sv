module rv32i_branch_unit (
  input  logic [2:0]  funct3_i,
  input  logic [31:0] rs1_i,
  input  logic [31:0] rs2_i,
  output logic        taken_o
);
  always_comb begin
    case (funct3_i)
      3'b000: taken_o = (rs1_i == rs2_i);                    // BEQ
      3'b001: taken_o = (rs1_i != rs2_i);                    // BNE
      3'b100: taken_o = ($signed(rs1_i) < $signed(rs2_i));   // BLT
      3'b101: taken_o = ($signed(rs1_i) >= $signed(rs2_i));  // BGE
      3'b110: taken_o = (rs1_i < rs2_i);                     // BLTU
      3'b111: taken_o = (rs1_i >= rs2_i);                    // BGEU
      default: taken_o = 1'b0;
    endcase
  end
endmodule
