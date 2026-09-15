module instruction_sram #(
  parameter integer WORDS = 256,
  parameter INIT_FILE = ""
) (
  input  logic [31:0] addr_i,
  output logic [31:0] rdata_o,
  output logic        fault_o
);
  logic [31:0] mem [0:WORDS-1];
  integer i;

  initial begin
    // NOP-fill unprogrammed instruction space.
    for (i = 0; i < WORDS; i = i + 1)
      mem[i] = 32'h0000_0013; // addi x0,x0,0
    if (INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  always_comb begin
    if ((addr_i[1:0] == 2'b00) && (addr_i[31:2] < WORDS)) begin
      rdata_o = mem[addr_i[31:2]];
      fault_o = 1'b0;
    end else begin
      rdata_o = 32'h0000_0013;
      fault_o = 1'b1;
    end
  end
endmodule
