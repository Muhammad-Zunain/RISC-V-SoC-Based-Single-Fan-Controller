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

`ifdef ASIC_USE_SRAM_MACROS
  // The real macro (ram_256x16A x2, see asic_sram_macro_stubs.sv) has no
  // per-byte write enable: each 16-bit half can only be written whole.
  // A single-byte store (SB) therefore needs a read-modify-write: read the
  // current word, merge in the new byte(s), then write the full word back.
  // Aligned SW/SH stores still complete in one cycle as before.
  typedef enum logic {ST_IDLE, ST_RMW_WRITE} rmw_state_e;
  rmw_state_e state_q, state_d;

  logic              need_rmw;
  logic [ADDR_W-1:0] rmw_addr_q;
  logic [31:0]       rmw_wdata_q;
  logic [3:0]        rmw_wstrb_q;
  logic [31:0]       merged_word;

  logic              mem_en;
  logic              mem_we;
  logic [3:0]        mem_wmask;
  logic [31:0]       mem_wdata;
  logic [ADDR_W-1:0] mem_addr;

  assign need_rmw = write_i && !request_fault &&
      (((wstrb_i[1:0] != 2'b00) && (wstrb_i[1:0] != 2'b11)) ||
       ((wstrb_i[3:2] != 2'b00) && (wstrb_i[3:2] != 2'b11)));

  always_comb begin
    merged_word = ram_q;
    if (rmw_wstrb_q[0]) merged_word[7:0]   = rmw_wdata_q[7:0];
    if (rmw_wstrb_q[1]) merged_word[15:8]  = rmw_wdata_q[15:8];
    if (rmw_wstrb_q[2]) merged_word[23:16] = rmw_wdata_q[23:16];
    if (rmw_wstrb_q[3]) merged_word[31:24] = rmw_wdata_q[31:24];
  end

  always_comb begin
    mem_en    = 1'b0;
    mem_we    = 1'b0;
    mem_wmask = 4'b0000;
    mem_wdata = 32'd0;
    mem_addr  = ram_addr;

    case (state_q)
      ST_IDLE: begin
        if (req_i && !request_fault) begin
          mem_en = 1'b1;
          if (need_rmw) begin
            mem_we    = 1'b0;
            mem_wmask = 4'b0000;
          end
          else begin
            mem_we    = write_i;
            mem_wmask = wstrb_i;
            mem_wdata = wdata_i;
          end
        end
      end
      ST_RMW_WRITE: begin
        mem_en    = 1'b1;
        mem_we    = 1'b1;
        mem_wmask = 4'b1111;
        mem_wdata = merged_word;
        mem_addr  = rmw_addr_q;
      end
      default: ;
    endcase
  end

  always_comb begin
    state_d = state_q;
    case (state_q)
      ST_IDLE:      state_d = (req_i && !request_fault && need_rmw) ? ST_RMW_WRITE : ST_IDLE;
      ST_RMW_WRITE: state_d = ST_IDLE;
      default:      state_d = ST_IDLE;
    endcase
  end

  asic_config_mem #(
    .WORDS     (WORDS),
    .ADDR_W    (ADDR_W),
    .INIT_FILE (INIT_FILE)
  ) u_cfg_ip (
    .clk_i   (clk_i),
    .en_i    (mem_en),
    .we_i    (mem_we),
    .wmask_i (mem_wmask),
    .addr_i  (mem_addr),
    .wdata_i (mem_wdata),
    .rdata_o (ram_q)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state_q         <= ST_IDLE;
      pending_q       <= 1'b0;
      fault_pending_q <= 1'b0;
    end
    else begin
      state_q <= state_d;

      pending_q <= (state_q == ST_IDLE && req_i && !need_rmw) ||
                   (state_q == ST_RMW_WRITE);

      if (state_q == ST_IDLE && req_i)
        fault_pending_q <= request_fault;

      if (state_q == ST_IDLE && req_i && !request_fault && need_rmw) begin
        rmw_addr_q  <= ram_addr;
        rmw_wdata_q <= wdata_i;
        rmw_wstrb_q <= wstrb_i;
      end
    end
  end
`else
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
`endif

  assign ready_o = pending_q;
  assign fault_o = pending_q && fault_pending_q;
  assign rdata_o = fault_o ? 32'd0 : ram_q;

endmodule
