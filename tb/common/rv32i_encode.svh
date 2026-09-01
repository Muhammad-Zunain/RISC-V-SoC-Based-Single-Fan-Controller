`ifndef RV32I_ENCODE_SVH
`define RV32I_ENCODE_SVH

function automatic [31:0] enc_r(
  input [6:0] f7,
  input [4:0] rs2,
  input [4:0] rs1,
  input [2:0] f3,
  input [4:0] rd,
  input [6:0] op
);
  enc_r = {f7, rs2, rs1, f3, rd, op};
endfunction

function automatic [31:0] enc_i(
  input integer imm,
  input [4:0] rs1,
  input [2:0] f3,
  input [4:0] rd,
  input [6:0] op
);
  reg [11:0] x;
  begin
    x = imm[11:0];
    enc_i = {x, rs1, f3, rd, op};
  end
endfunction

function automatic [31:0] enc_s(
  input integer imm,
  input [4:0] rs2,
  input [4:0] rs1,
  input [2:0] f3
);
  reg [11:0] x;
  begin
    x = imm[11:0];
    enc_s = {x[11:5], rs2, rs1, f3, x[4:0], 7'b0100011};
  end
endfunction

function automatic [31:0] enc_b(
  input integer imm,
  input [4:0] rs2,
  input [4:0] rs1,
  input [2:0] f3
);
  reg [12:0] x;
  begin
    x = imm[12:0];
    enc_b = {x[12], x[10:5], rs2, rs1, f3, x[4:1], x[11], 7'b1100011};
  end
endfunction

function automatic [31:0] enc_u(
  input [19:0] imm20,
  input [4:0] rd,
  input [6:0] op
);
  enc_u = {imm20, rd, op};
endfunction

function automatic [31:0] enc_j(
  input integer imm,
  input [4:0] rd
);
  reg [20:0] x;
  begin
    x = imm[20:0];
    enc_j = {x[20], x[10:1], x[11], x[19:12], rd, 7'b1101111};
  end
endfunction

`endif
