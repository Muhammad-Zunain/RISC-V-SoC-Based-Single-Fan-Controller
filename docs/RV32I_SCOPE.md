# RV32I Core Scope

The CPU is a synthesizable **32-bit multicycle RV32I educational processor** with separate instruction-memory and data/MMIO request-response interfaces.

The design is intentionally compact. It does not implement pipelining, caches, an MMU, compressed instructions, or advanced processor features.

---

## Multicycle Architecture

The CPU uses an explicit finite-state machine to execute instructions across multiple clock cycles.

The current states are:

```text
ST_FETCH_REQ   = 0
ST_FETCH_WAIT  = 1
ST_DECODE      = 2
ST_EXECUTE     = 3
ST_ALU_WB      = 4
ST_MEM_REQ     = 5
ST_MEM_WAIT    = 6
ST_LOAD_WB     = 7
ST_TRAP        = 8