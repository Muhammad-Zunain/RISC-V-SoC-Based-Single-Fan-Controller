module config_ip_wrapper #(
  parameter integer WORDS = 256,
  parameter logic [31:0] BASE_ADDR = 32'h2000_0000,
  parameter INIT_FILE = "firmware/config_demo.hex"
) (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        req_i,
  input  logic        write_i,

  input  logic [31:0] addr_i,
  input  logic [31:0] wdata_i,
  input  logic [3:0]  wstrb_i,

  output logic        ready_o,
  output logic [31:0] rdata_o,
  output logic        fault_o
);

  localparam integer ADDR_W = $clog2(WORDS);
  localparam logic [31:0] END_ADDR = BASE_ADDR + (WORDS * 4);

  logic [31:0]       word_offset;
  logic [ADDR_W-1:0] ram_addr;
  logic [31:0]       ram_q;

  logic pending_q;
  logic fault_pending_q;
  logic request_fault;

  always_comb begin
    request_fault = 1'b0;

    if (addr_i < BASE_ADDR)
      request_fault = 1'b1;
    else if (addr_i >= END_ADDR)
      request_fault = 1'b1;
  end

  assign word_offset = (addr_i - BASE_ADDR) >> 2;

  assign ram_addr =
      request_fault ?
      {ADDR_W{1'b0}} :
      word_offset[ADDR_W-1:0];

  // Technology-independent configuration-memory backend.
  // Keep the legacy instance name for current directed TB hierarchy.
  asic_config_mem #(
    .WORDS     (WORDS),
    .ADDR_W    (ADDR_W),
    .INIT_FILE (INIT_FILE)
  ) u_cfg_ip (
    .clk_i   (clk_i),
    .en_i    (req_i && !request_fault),
    .we_i    (write_i),
    .wmask_i (wstrb_i),
    .addr_i  (ram_addr),
    .wdata_i (wdata_i),
    .rdata_o (ram_q)
  );

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
  assign rdata_o = fault_o ? 32'd0 : ram_q;

endmodule
