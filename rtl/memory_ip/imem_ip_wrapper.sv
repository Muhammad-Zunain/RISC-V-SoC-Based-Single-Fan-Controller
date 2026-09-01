module imem_ip_wrapper #(
  parameter integer WORDS = 1024,
  parameter INIT_FILE     = "firmware/soc_demo.hex"
) (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        req_i,
  input  logic [31:0] addr_i,

  output logic        ready_o,
  output logic [31:0] rdata_o,
  output logic        fault_o
);

  localparam integer ADDR_W    = $clog2(WORDS);
  localparam integer MEM_BYTES = WORDS * 4;

  logic [ADDR_W-1:0] ram_addr;
  logic [31:0]       ram_q;

  logic pending_q;
  logic fault_pending_q;
  logic request_fault;

  // Instruction accesses must be 32-bit aligned and inside IMEM.
  always_comb begin
    request_fault = 1'b0;

    if (addr_i[1:0] != 2'b00)
      request_fault = 1'b1;
    else if (addr_i >= MEM_BYTES)
      request_fault = 1'b1;
  end

  assign ram_addr =
      request_fault ?
      {ADDR_W{1'b0}} :
      addr_i[ADDR_W+1:2];

  // Technology-independent memory backend.
  // Instance name is intentionally kept as u_imem_ip so existing directed
  // testbench hierarchy remains valid during the ASIC migration.
  asic_imem #(
    .WORDS     (WORDS),
    .ADDR_W    (ADDR_W),
    .INIT_FILE (INIT_FILE)
  ) u_imem_ip (
    .clk_i   (clk_i),
    .en_i    (req_i && !request_fault),
    .addr_i  (ram_addr),
    .rdata_o (ram_q)
  );

  // Request at cycle N -> ready/data at cycle N+1.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pending_q       <= 1'b0;
      fault_pending_q <= 1'b0;
    end
    else begin
      pending_q <= req_i;

      if (req_i)
        fault_pending_q <= request_fault;
    end
  end

  assign ready_o = pending_q;
  assign fault_o = pending_q && fault_pending_q;

  // Return a NOP on an invalid access. fault_o still causes the CPU trap.
  assign rdata_o = fault_o ? 32'h0000_0013 : ram_q;

endmodule
