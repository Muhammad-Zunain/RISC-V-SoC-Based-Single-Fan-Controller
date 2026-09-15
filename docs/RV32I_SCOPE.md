# RV32I Core Scope

The CPU is a synthesizable **32-bit multicycle RV32I educational processor** with separate instruction-memory and data/MMIO request-response interfaces.

The core implements the complete base RV32I integer instruction set used by this project: integer ALU operations, branches, JAL/JALR, loads/stores, FENCE, ECALL, and EBREAK. It intentionally does **not** implement compressed instructions, multiplication/division, atomics, floating point, caches, an MMU, pipelining, interrupts, privileged CSRs, or a full privileged trap handler.

The exception-cause numbers follow RISC-V conventions, but this educational core uses a **halt-on-trap** model rather than `mtvec/mepc/mcause` machine-mode trap handling.

## Multicycle Architecture

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
```

The explicit request/wait states match the one-cycle synchronous memory wrapper interface. No SDC `set_multicycle_path` exception is required merely because the CPU is architecturally multicycle; the RTL registers and FSM already define the cycle boundaries.

## Architectural rules implemented

- XLEN = 32 and `x0` is hard-wired to zero.
- Base instruction alignment is 4 bytes (`IALIGN=32`).
- JAL writes `pc+4`; JALR clears target bit 0 before the alignment check.
- Taken branch/JAL/JALR targets that are not 4-byte aligned trap.
- Loads/stores implement little-endian LB/LBU/LH/LHU/LW and SB/SH/SW behavior.
- Naturally misaligned halfword/word accesses trap in this implementation.
- FENCE is accepted and completed as an in-order no-op in this single-hart/simple-memory implementation.
- ECALL/EBREAK enter the simplified trap/halt state.
