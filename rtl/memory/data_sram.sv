module data_sram #(
  parameter integer WORDS = 256
) (
  input  logic        clk_i,
  input  logic        we_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] wdata_i,
  input  logic [3:0]  wstrb_i,
  output logic [31:0] rdata_o
);
  logic [31:0] mem [0:WORDS-1];
  wire [31:0] word_index = addr_i >> 2;
  integer i;

  initial begin
    for (i = 0; i < WORDS; i = i + 1)
      mem[i] = 32'd0;
  end

  always_comb begin
    if (word_index < WORDS)
      rdata_o = mem[word_index];
    else
      rdata_o = 32'd0;
  end

  always @(posedge clk_i) begin
    if (we_i && (word_index < WORDS)) begin
      if (wstrb_i[0]) mem[word_index][7:0]   <= wdata_i[7:0];
      if (wstrb_i[1]) mem[word_index][15:8]  <= wdata_i[15:8];
      if (wstrb_i[2]) mem[word_index][23:16] <= wdata_i[23:16];
      if (wstrb_i[3]) mem[word_index][31:24] <= wdata_i[31:24];
    end
  end
endmodule
