# RISC-V SoC-Based Single-Fan Controller with PWM, SPI, and UART

## Complete End-to-End RTL, Verification, and ASIC-Oriented Architecture Guide

---

## 1. Project Overview

This project implements a synthesizable **32-bit RV32I multicycle System-on-Chip (SoC)** that controls one simulated fan through PWM and communicates with external devices through UART and SPI.

The design was developed and verified at RTL level in SystemVerilog. The active architecture is now **ASIC-oriented**: the processor and peripherals are technology-independent, while the memories are accessed through wrappers that can use behavioral SRAM models during simulation and real SRAM/ROM macros during ASIC synthesis and physical design.

The complete project contains:

- A custom 32-bit RV32I multicycle processor
- A multicycle finite-state-machine controller
- 32 x 32-bit integer register file
- Arithmetic Logic Unit (ALU)
- Immediate generator
- Instruction decoder
- Branch comparison unit
- Load/Store Unit (LSU)
- Instruction-memory interface and wrapper
- Data-memory interface and wrapper
- Configuration-memory interface and wrapper
- ASIC-neutral SRAM/ROM abstraction
- Memory-mapped I/O decoder
- PWM fan controller
- UART transmitter
- UART receiver
- UART memory-mapped peripheral
- SPI Mode-0 master
- SPI memory-mapped peripheral
- Virtual fan simulation model
- UART terminal simulation model
- SPI slave simulation model
- Demo RV32I firmware
- Directed self-checking SystemVerilog testbenches
- ModelSim/QuestaSim compile and regression scripts
- ASIC synthesis file list and initial SDC constraints
- ASIC top-level wrapper for later Cadence Genus/Innovus implementation

The current RTL has passed functional verification, including CPU, memory, peripheral, integration, exception, and full-SoC tests.

---

## 2. Project Objective

The project demonstrates how a small embedded system can be built around a custom RISC-V processor.

The SoC must be able to:

1. Fetch and execute RV32I instructions.
2. Read configuration values from on-chip configuration memory.
3. Configure a PWM controller from software.
4. Generate a programmable PWM signal for one fan.
5. Transmit a byte through UART.
6. Receive a byte through UART.
7. Transmit a byte as an SPI master.
8. Receive a byte from an SPI slave.
9. Store received peripheral data in Data SRAM.
10. Detect illegal accesses and CPU exceptions.
11. Provide a verification environment that checks the complete system automatically.
12. Support a later ASIC flow using Cadence Genus for synthesis and Cadence Innovus for physical design.

The design intentionally does **not** implement:

- Pipelining
- Caches
- MMU
- Branch prediction
- Compressed RISC-V instructions
- Floating-point instructions
- Multiply/divide extension
- CSR subsystem
- Interrupt controller
- Multiple CPU cores
- Multiple fans
- Closed-loop RPM feedback
- PID control

The focus is a small, understandable, synthesizable SoC with complete end-to-end verification.

---

# 3. High-Level Architecture

```text
                                   +---------------------------+
                                   |                           |
                                   |   Multicycle RV32I CPU    |
                                   |                           |
                                   +-------------+-------------+
                                                 |
                        +------------------------+-------------------------+
                        |                                                  |
                        |                                                  |
                 Instruction Bus                                   Data / MMIO Bus
                        |                                                  |
                        v                                                  v
              +--------------------+                            +---------------------+
              |  IMEM Wrapper      |                            |    MMIO Decoder     |
              +---------+----------+                            +----------+----------+
                        |                                                  |
                        v                         +------------------------+-----------------------+
              +--------------------+              |             |              |        |        |
              | ASIC-Neutral IMEM  |              v             v              v        v        v
              +---------+----------+         +---------+   +---------+     +-------+ +------+ +------+
                        |                    |  DMEM   |   |  CFG    |     |  PWM  | | UART | | SPI  |
                        |                    | Wrapper |   | Wrapper |     +---+---+ +--+---+ +--+---+
                        |                    +----+----+   +----+----+         |        |        |
                        |                         |             |              |        |        |
                        v                         v             v              v        v        v
             Simulation: behavioral       ASIC-Neutral   ASIC-Neutral      Fan      TX/RX    Master
             synchronous memory           Data SRAM      Config SRAM       PWM
                        |                         |             |
                        +-------------+-----------+-------------+
                                      |
                                      v
                            ASIC macro replacement
                            during synthesis / P&R
```

The CPU uses a dedicated instruction interface and a separate data/MMIO interface. This gives the design a Harvard-style processor interface while allowing Data SRAM, Config SRAM, PWM, UART, and SPI to share one address-decoded data bus.

---

# 4. Top-Level Functional Data Flow

The end-to-end flow is:

```text
Demo Firmware
     |
     v
Instruction Memory
     |
     v
RV32I CPU
     |
     +--------------------> Read configuration values
     |                         from Config SRAM
     |
     +--------------------> Program PWM period/duty/enable
     |
     +--------------------> Send UART byte
     |
     +--------------------> Start SPI transaction
     |                         and wait for completion
     |
     +--------------------> Store SPI RX byte in Data SRAM
     |
     +--------------------> Wait for UART RX byte
     |
     +--------------------> Store UART RX byte in Data SRAM
     |
     v
Infinite software loop
```

During verification, external models provide the environment:

```text
PWM output  ---> Virtual Fan Model
UART TX     ---> UART Terminal Model
UART RX     <--- Testbench-generated serial stream
SPI MOSI    ---> SPI Slave Model
SPI MISO    <--- SPI Slave Model response
```

---

# 5. Global Package: `soc_pkg.sv`

The `soc_pkg` package contains constants shared across the design.

It defines:

- Global memory-map base addresses
- Peripheral register offsets
- ALU operation encodings
- Immediate format encodings
- Writeback source encodings
- RISC-V-compatible trap cause values

## 5.1 Global base addresses

| Block | Base Address |
|---|---:|
| Reset PC / IMEM | `0x0000_0000` |
| Data SRAM | `0x1000_0000` |
| Config SRAM | `0x2000_0000` |
| PWM | `0x4000_0000` |
| UART | `0x4000_1000` |
| SPI | `0x4000_2000` |

The reset PC is `0x0000_0000`, so after reset the processor begins fetching the first instruction from the beginning of Instruction Memory.

## 5.2 ALU operation codes

The package defines internal operation codes for:

```text
ADD
SUB
SLL
SLT
SLTU
XOR
SRL
SRA
OR
AND
```

## 5.3 Immediate types

The decoder and immediate generator use these internal formats:

```text
IMM_I
IMM_S
IMM_B
IMM_U
IMM_J
```

## 5.4 Writeback sources

The architecture defines three writeback classes:

```text
WB_ALU  = ALU result
WB_MEM  = load result
WB_PC4  = PC + 4 for JAL/JALR
```

## 5.5 Trap causes

The processor uses standard RISC-V cause numbers for the supported exceptions:

| Cause | Meaning |
|---:|---|
| 0 | Instruction address misaligned |
| 1 | Instruction access fault |
| 2 | Illegal instruction |
| 3 | Breakpoint / EBREAK |
| 4 | Load address misaligned |
| 5 | Load access fault |
| 6 | Store address misaligned |
| 7 | Store access fault |
| 11 | ECALL |

The current core does not implement `mtvec`, `mepc`, or `mcause` CSRs. Instead, a detected exception halts the processor and exposes the cause through debug/status outputs.

---

# 6. Multicycle RV32I CPU: `rv32i_core.sv`

The processor is a **multicycle**, not a pipelined, implementation.

A single instruction is divided across several FSM states. This allows synchronous memories to be used naturally and reduces the amount of combinational work required in one clock cycle compared with a large single-cycle implementation.

The CPU contains two external request/response interfaces:

### Instruction interface

```text
imem_req_o
imem_addr_o
imem_ready_i
imem_rdata_i
imem_fault_i
```

### Data/MMIO interface

```text
dmem_req_o
dmem_write_o
dmem_addr_o
dmem_wdata_o
dmem_wstrb_o

dmem_ready_i
dmem_rdata_i
dmem_fault_i
```

The core also exports:

```text
pc_o
instr_o
halted_o
trap_o
trap_cause_o
state_o
```

These are used for verification and debug.

---

# 7. CPU Multicycle FSM

The CPU uses nine states:

| State Value | State Name | Purpose |
|---:|---|---|
| 0 | `ST_FETCH_REQ` | Start an instruction-memory transaction |
| 1 | `ST_FETCH_WAIT` | Wait for synchronous instruction memory |
| 2 | `ST_DECODE` | Decode instruction and capture operands/immediate |
| 3 | `ST_EXECUTE` | Perform ALU/address/branch/jump operation |
| 4 | `ST_ALU_WB` | Write ALU result to destination register |
| 5 | `ST_MEM_REQ` | Start Data SRAM / Config SRAM / MMIO transaction |
| 6 | `ST_MEM_WAIT` | Wait for the selected data target to acknowledge |
| 7 | `ST_LOAD_WB` | Write load result to destination register |
| 8 | `ST_TRAP` | Permanent halted trap state |

## 7.1 `ST_FETCH_REQ`

The CPU asserts:

```text
imem_req_o = 1
imem_addr_o = current PC
```

The request is generated only in this state.

This is important because it prevents a memory request from being issued repeatedly while the CPU waits for the response.

## 7.2 `ST_FETCH_WAIT`

The CPU waits for:

```text
imem_ready_i = 1
```

When the memory reply arrives, `imem_rdata_i` is captured into the instruction register.

If the response also indicates `imem_fault_i = 1`, the processor generates an instruction access fault instead of continuing execution.

## 7.3 `ST_DECODE`

The current instruction is decoded.

The CPU captures:

```text
rs1_q = value of rs1
rs2_q = value of rs2
imm_q = generated immediate
```

These captured values remain stable for the rest of the multicycle instruction.

Illegal instructions, ECALL, and EBREAK are detected at this stage.

## 7.4 `ST_EXECUTE`

This stage performs the main operation.

Depending on instruction type, it can:

- Compute an ALU result
- Compute a memory effective address
- Generate store byte strobes and aligned write data
- Compare branch operands
- Calculate JAL/JALR targets
- Update PC for branch/jump/FENCE

For memory instructions the following values are stored:

```text
effective_addr_q
store_wdata_q
store_wstrb_q
```

For normal ALU instructions:

```text
alu_result_q
```

is stored for the next writeback state.

## 7.5 `ST_ALU_WB`

The captured ALU result is written to the destination register.

After writeback:

```text
PC = PC + 4
```

and the CPU returns to `ST_FETCH_REQ`.

## 7.6 `ST_MEM_REQ`

The CPU starts exactly one Data/MMIO transaction:

```text
dmem_req_o   = 1
dmem_addr_o  = effective_addr_q
dmem_write_o = load/store direction
dmem_wdata_o = store_wdata_q
dmem_wstrb_o = store_wstrb_q
```

## 7.7 `ST_MEM_WAIT`

The CPU waits for:

```text
dmem_ready_i = 1
```

If the request was a store, completion advances the PC immediately.

If it was a load, returned data is processed by the LSU and captured in `load_data_q`.

If `dmem_fault_i = 1`, the processor raises a load or store access fault.

## 7.8 `ST_LOAD_WB`

The processed load value is written to the destination register.

Then:

```text
PC = PC + 4
```

and the next instruction fetch begins.

## 7.9 `ST_TRAP`

When a trap occurs:

```text
halted_o = 1
trap_o = 1
trap_cause_o = detected cause
state_q = ST_TRAP
```

The processor remains in this state until reset.

---

# 8. CPU Cycle Counts

With the current one-cycle synchronous request/ready memory interface, representative instruction counts are:

| Instruction Class | State Sequence | Cycles |
|---|---|---:|
| R-type / OP-IMM / LUI / AUIPC | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE → ALU_WB | 5 |
| Load | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE → MEM_REQ → MEM_WAIT → LOAD_WB | 7 |
| Store | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE → MEM_REQ → MEM_WAIT | 6 |
| Branch | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE | 4 |
| JAL/JALR | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE | 4 |
| FENCE | FETCH_REQ → FETCH_WAIT → DECODE → EXECUTE | 4 |

A dedicated cycle-count testbench verifies a sequence of eight instructions:

```text
ADD
SUB
AND
OR
LW
SW
JAL
LW
```

Expected total:

```text
5 + 5 + 5 + 5 + 7 + 6 + 4 + 7 = 44 cycles
```

This confirms the processor is genuinely multicycle.

---

# 9. Instruction Decoder: `rv32i_decoder.sv`

The decoder examines:

```text
opcode = instr[6:0]
funct3 = instr[14:12]
funct7 = instr[31:25]
```

and generates control signals such as:

```text
reg_write
mem_valid
mem_write
alu_op
alu_src_imm
alu_a_pc
alu_a_zero
imm_sel
wb_sel
branch
jal
jalr
ecall
ebreak
fence
illegal
```

## 9.1 Supported RV32I instruction groups

### Upper-immediate

```text
LUI
AUIPC
```

### Jump

```text
JAL
JALR
```

### Branch

```text
BEQ
BNE
BLT
BGE
BLTU
BGEU
```

### Loads

```text
LB
LH
LW
LBU
LHU
```

### Stores

```text
SB
SH
SW
```

### Immediate arithmetic/logical

```text
ADDI
SLTI
SLTIU
XORI
ORI
ANDI
SLLI
SRLI
SRAI
```

### Register-register

```text
ADD
SUB
SLL
SLT
SLTU
XOR
SRL
SRA
OR
AND
```

### System/base ordering

```text
FENCE
ECALL
EBREAK
```

`FENCE` is treated as an in-order no-operation because there are no caches, speculation, or out-of-order units requiring explicit memory-order hardware.

CSR instructions are not implemented.

If an encoding is illegal, all state-changing controls such as register write, memory access, branch, and jump are disabled before the core takes the trap.

---

# 10. Immediate Generator: `rv32i_imm_gen.sv`

The Immediate Generator extracts and sign-extends the immediate field according to instruction format.

It supports:

### I-type

Used by:

```text
ADDI and other OP-IMM instructions
Loads
JALR
```

### S-type

Used by:

```text
SB
SH
SW
```

### B-type

Used by conditional branches.

The generated branch immediate includes the required low zero bit because branch targets are encoded in multiples of two bytes.

### U-type

Used by:

```text
LUI
AUIPC
```

The immediate occupies bits `[31:12]` and the lower twelve bits are zero.

### J-type

Used by `JAL`.

The immediate is reconstructed into a signed PC-relative byte offset.

---

# 11. Register File: `rv32i_regfile.sv`

The register file contains:

```text
32 registers x 32 bits
```

It has:

- Two combinational read ports
- One synchronous write port

The ports correspond to:

```text
rs1
rs2
rd
```

Register `x0` is permanently zero.

Any read of `x0` returns:

```text
0x00000000
```

Any attempted write to `x0` is ignored.

On reset, all stored registers are cleared.

---

# 12. ALU: `rv32i_alu.sv`

The Arithmetic Logic Unit is combinational and supports:

| Operation | Function |
|---|---|
| `ADD` | 32-bit addition |
| `SUB` | 32-bit subtraction |
| `SLL` | Logical left shift |
| `SLT` | Signed less-than comparison |
| `SLTU` | Unsigned less-than comparison |
| `XOR` | Bitwise XOR |
| `SRL` | Logical right shift |
| `SRA` | Arithmetic right shift |
| `OR` | Bitwise OR |
| `AND` | Bitwise AND |

Shift amount uses only the low five bits of operand B because RV32I registers are 32 bits wide.

The ALU is also reused for effective address generation:

```text
Load/store address = rs1 + immediate
```

and for LUI/AUIPC operand processing.

## 12.1 ALU input-A selection

The core can select:

```text
0        -> LUI
PC       -> AUIPC
rs1_q    -> normal arithmetic/address operations
```

## 12.2 ALU input-B selection

The core selects either:

```text
rs2_q
```

or:

```text
imm_q
```

according to decoder control.

---

# 13. Branch Unit: `rv32i_branch_unit.sv`

The branch unit is combinational and receives:

```text
funct3
rs1
rs2
```

It implements:

| Branch | Comparison |
|---|---|
| BEQ | `rs1 == rs2` |
| BNE | `rs1 != rs2` |
| BLT | signed `rs1 < rs2` |
| BGE | signed `rs1 >= rs2` |
| BLTU | unsigned `rs1 < rs2` |
| BGEU | unsigned `rs1 >= rs2` |

For a taken branch:

```text
new PC = current PC + branch immediate
```

For a not-taken branch:

```text
new PC = current PC + 4
```

---

# 14. JAL and JALR Control Flow

## 14.1 JAL

For `JAL`:

```text
rd = PC + 4
PC = PC + J-immediate
```

## 14.2 JALR

For `JALR`:

```text
rd = PC + 4
PC = (rs1 + I-immediate) & 0xFFFF_FFFE
```

Because the design implements RV32I without the compressed `C` extension, valid instruction addresses must be **4-byte aligned**.

Therefore the CPU checks:

```text
control_target[1:0] == 2'b00
```

and raises an instruction-address-misaligned trap if the target is not word aligned.

---

# 15. Load/Store Unit: `rv32i_lsu.sv`

The LSU performs three main jobs:

1. Detect address misalignment.
2. Generate store data and byte write strobes.
3. Extract and sign/zero-extend load data.

## 15.1 Alignment checking

### Byte accesses

```text
LB / LBU / SB
```

can access any byte address.

### Halfword accesses

```text
LH / LHU / SH
```

require:

```text
addr[0] = 0
```

### Word accesses

```text
LW / SW
```

require:

```text
addr[1:0] = 00
```

Misaligned accesses generate load/store misalignment traps before a bus transaction is started.

## 15.2 Store byte strobes

The data bus uses four byte enables:

```text
wstrb[3:0]
```

Each bit represents one 8-bit lane:

| Strobe | Byte Lane |
|---|---|
| `0001` | bits `[7:0]` |
| `0010` | bits `[15:8]` |
| `0100` | bits `[23:16]` |
| `1000` | bits `[31:24]` |

For `SB`, the selected byte is shifted into the correct lane.

For `SH`, either:

```text
0011
```

or:

```text
1100
```

is generated.

For `SW`:

```text
1111
```

is generated.

## 15.3 Load formatting

The LSU implements:

```text
LB  -> byte + sign extension
LH  -> halfword + sign extension
LW  -> full 32-bit word
LBU -> byte + zero extension
LHU -> halfword + zero extension
```

The byte/halfword is selected using low address bits from the effective address.

---

# 16. Trap and Exception Handling

The CPU checks exceptions in different FSM stages.

## 16.1 Fetch-stage checks

### Instruction address misalignment

Detected in `ST_FETCH_REQ`.

### Instruction access fault

Detected in `ST_FETCH_WAIT` when Instruction Memory returns `fault` with `ready`.

## 16.2 Decode-stage checks

Detected in `ST_DECODE`:

```text
Illegal instruction
EBREAK
ECALL
```

## 16.3 Execute-stage checks

Detected in `ST_EXECUTE`:

```text
Branch/JAL/JALR target misalignment
Load address misalignment
Store address misalignment
```

## 16.4 Memory-response checks

Detected in `ST_MEM_WAIT`:

```text
Load access fault
Store access fault
```

## 16.5 Trap priority

A trap has priority over normal architectural state updates.

The sequential core logic first checks `trap_request`. If it is asserted, the processor enters `ST_TRAP` instead of performing normal instruction completion.

Register writeback is also explicitly protected:

```systemverilog
if (!halted_o && !trap_request)
```

This prevents an instruction such as a misaligned JAL/JALR from writing `PC+4` to the destination register while simultaneously trapping.

---

# 17. Instruction Memory Wrapper: `imem_ip_wrapper.sv`

Instruction Memory is accessed through a technology-independent wrapper.

Default organization:

```text
256 words x 32 bits = 1024 bytes = 1 KiB
```

Address range:

```text
0x0000_0000 - 0x0000_03FF
```

The wrapper performs:

- Word-alignment checking
- IMEM range checking
- Byte-address to word-address conversion
- One-cycle request/ready protocol generation
- Fault registration
- Connection to the active memory backend

## 17.1 Address conversion

The CPU uses byte addresses.

The memory uses word addresses.

Therefore:

```text
RAM address = CPU address >> 2
```

## 17.2 Fault behavior

A request faults if:

```text
addr[1:0] != 00
```

or the address is outside the configured IMEM capacity.

For a faulting access, the wrapper returns an RV32I NOP value:

```text
0x00000013
```

but also asserts `fault_o`, so the processor takes an instruction-access trap.

## 17.3 Request/ready timing

Conceptually:

```text
Cycle N:
    req_i  = 1
    addr_i = valid

Cycle N+1:
    ready_o = 1
    rdata_o = valid
```

The CPU waits in `ST_FETCH_WAIT` until this response is visible.

---

# 18. Data SRAM Wrapper: `dmem_ip_wrapper.sv`

Default Data SRAM organization:

```text
256 words x 32 bits = 1 KiB
```

Address range:

```text
0x1000_0000 - 0x1000_03FF
```

The wrapper:

- Checks the address against Data SRAM range
- Subtracts the Data SRAM base address
- Converts byte offset into word address
- Passes byte write-mask signals to the memory backend
- Generates one-cycle request/ready behavior
- Reports out-of-range access faults

Alignment is not duplicated in the wrapper because the LSU already checks byte/halfword/word alignment before issuing the transaction.

---

# 19. Configuration SRAM Wrapper: `config_ip_wrapper.sv`

Default Config SRAM organization:

```text
256 words x 32 bits = 1024 bytes = 1 KiB
```

Address range:

```text
0x2000_0000 - 0x2000_03FF
```

The wrapper behaves like the Data SRAM wrapper, including:

- Base/range checking
- Word-address conversion
- Byte write mask forwarding
- Registered request/ready response
- Access fault generation

The configuration SRAM is used by firmware as a software-readable configuration table.

---

# 20. ASIC-Neutral Memory Backends

The active memory backends are:

```text
asic_imem
asic_dmem
asic_config_mem
```

These modules deliberately support two modes.

---

## 20.1 RTL simulation mode

When `ASIC_USE_SRAM_MACROS` is **not** defined, ModelSim/QuestaSim uses behavioral synchronous memories such as:

```systemverilog
logic [31:0] mem [0:WORDS-1];
```

This mode allows:

- Firmware loading with `$readmemh`
- Hierarchical testbench memory preload
- Directed memory inspection
- Simple functional simulation

`asic_imem` initializes unused instruction words to the standard RV32I NOP:

```text
0x00000013
```

`asic_dmem` initializes data words to zero for simulation.

`asic_config_mem` can preload the configuration HEX file.

The actual memory arrays are **not reset every time the SoC reset is asserted**, which is closer to real SRAM behavior than clearing all memory on reset.

---

## 20.2 ASIC synthesis mode

When:

```text
ASIC_USE_SRAM_MACROS
```

is defined, behavioral arrays are bypassed and the modules instantiate abstract macro boundaries:

```text
asic_imem_macro
asic_dmem_macro
asic_config_macro
```

The intended physical organizations are:

| Macro | Organization | Purpose |
|---|---:|---|
| IMEM | 256 x 32 | instruction memory / ROM-like storage |
| DMEM | 256 x 32 | 1RW data SRAM with byte masks |
| Config | 256 x 32 | 1RW configuration SRAM with byte masks |

The current stubs are **not physical SRAMs**. They are placeholders that preserve the logical interface until a PDK/memory compiler is selected.

The exact interface expected from the later custom macro adapter is documented in `docs/ASIC_MEMORY_MACRO_CONTRACT.md`.

For final ASIC implementation, the stubs must be replaced or wrapped around real technology SRAMs/ROMs.

Typical macro deliverables required later are:

```text
.lib   -> timing and power
.lef   -> macro size, pins, obstruction geometry
.gds   -> physical layout
.v     -> logical Verilog model / black-box definition
.cdl or SPICE -> LVS / circuit-level verification
```

---

# 21. Why Intel M10K Is No Longer the Active Memory Architecture

Earlier FPGA versions of the project used Intel/Altera M10K RAM IP generated by Quartus.

Those legacy files may remain in the repository under the `quartus/` directory for reference, but the active ASIC flow does not depend on:

```text
M10K
altsyncram
.qip files
Quartus RAM IP simulation models
```

The active architecture is:

```text
CPU
 |
 v
Technology-independent memory wrapper
 |
 v
ASIC-neutral memory abstraction
 |
 +----------------------------+
 |                            |
 v                            v
ModelSim behavioral model    Real ASIC SRAM/ROM macro
```

This allows the CPU, MMIO subsystem, and peripherals to remain unchanged when the final PDK and SRAM compiler are selected.

---

# 22. MMIO Decoder: `mmio_decoder.sv`

The CPU data interface is shared between memory and peripherals.

The MMIO decoder examines the CPU address and produces one of:

```text
sel_dmem
sel_cfg
sel_pwm
sel_uart
sel_spi
```

If no valid target matches:

```text
fault_o = 1
```

## 22.1 Address decoding

### Data SRAM

Decoded using the configured Data SRAM base and depth.

### Config SRAM

Decoded using the configured Config SRAM base and depth.

### Peripheral pages

PWM, UART, and SPI each occupy one 4-KiB MMIO page:

```text
PWM  : 0x4000_0000 - 0x4000_0FFF
UART : 0x4000_1000 - 0x4000_1FFF
SPI  : 0x4000_2000 - 0x4000_2FFF
```

Within those pages, only documented register offsets perform meaningful actions. Unsupported offsets return zero on read or are ignored on write.

An address outside every valid region produces a CPU load/store access fault.

---

# 23. SoC Interconnect and Outstanding Transaction Control

`riscv_fan_soc.sv` connects the CPU, memories, MMIO decoder, and peripherals.

A key part of the SoC is the outstanding-transaction tracker:

```text
target_q
target_valid_q
peripheral_rdata_q
```

Possible target codes represent:

```text
NONE
DMEM
CFG
PWM
UART
SPI
FAULT
```

## 23.1 Why target tracking is required

The CPU generates `dmem_req_o` only in `ST_MEM_REQ`.

At the request edge, the SoC remembers which target was selected.

Then, while the CPU is in `ST_MEM_WAIT`, the SoC holds that destination until the response is returned.

This gives a clean transaction sequence:

```text
CPU ST_MEM_REQ
      |
      v
Address decode
      |
      v
Latch target
      |
      v
CPU ST_MEM_WAIT
      |
      v
Selected target replies
      |
      v
cpu_ready = 1
```

This is particularly important because the memory wrappers are synchronous while the peripheral register read data is combinational.

## 23.2 Peripheral read handling

PWM/UART/SPI read data is captured when the request is accepted:

```text
peripheral_rdata_q
```

The transaction is acknowledged one cycle later.

## 23.3 Preventing duplicate writes

Each peripheral receives:

```text
bus_valid_i = cpu_req && selected_target
```

and CPU request is asserted only in `ST_MEM_REQ`.

Therefore a write occurs once, rather than being repeated every cycle while the CPU waits in `ST_MEM_WAIT`.

---

# 24. Complete SoC Memory Map

| Region | Address / Range | Description |
|---|---|---|
| IMEM | `0x0000_0000 - 0x0000_03FF` | 4-KiB Instruction Memory |
| DMEM | `0x1000_0000 - 0x1000_03FF` | 4-KiB Data SRAM |
| Config | `0x2000_0000 - 0x2000_03FF` | 1-KiB Configuration SRAM |
| PWM Page | `0x4000_0000 - 0x4000_0FFF` | PWM registers |
| UART Page | `0x4000_1000 - 0x4000_1FFF` | UART registers |
| SPI Page | `0x4000_2000 - 0x4000_2FFF` | SPI registers |

---

# 25. PWM Peripheral: `pwm_peripheral.sv`

The PWM peripheral provides software-controlled pulse-width modulation.

Internal registers are:

```text
enable_q
period_q
duty_q
counter_q
```

## 25.1 PWM register map

Base:

```text
0x4000_0000
```

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x000` | CTRL | R/W | bit 0 = PWM enable |
| `0x004` | PERIOD | R/W | PWM period in system-clock cycles |
| `0x008` | DUTY | R/W | number of HIGH cycles per period |
| `0x00C` | COUNT | Read | current PWM counter value |

## 25.2 PWM generation rule

If disabled:

```text
pwm_o = 0
counter = 0
```

If `period = 0`:

```text
pwm_o = 0
counter = 0
```

If:

```text
duty >= period
```

then:

```text
pwm_o = 1
```

continuously while enabled.

Normally:

```text
pwm_o = 1 when counter < duty
pwm_o = 0 when counter >= duty
```

The counter runs from:

```text
0 ... period - 1
```

and then wraps to zero.

## 25.3 Demo configuration

The demo uses:

```text
Period = 100 cycles
Duty   = 30 cycles
```

so:

```text
Duty cycle = 30 / 100 = 30%
```

At a 50-MHz system clock, a 100-cycle PWM period corresponds to 2 us, or 500 kHz. The functional project requirement is the programmable duty behavior; later ASIC or system integration can change the programmed period as required by the real fan/interface target.

## 25.4 Partial writes

The PWM uses byte strobes when updating 32-bit registers, so partial byte writes can merge with existing PERIOD or DUTY values.

---

# 26. Virtual Fan Model: `virtual_fan_model.sv`

The Virtual Fan Model is a **testbench-only** block. It is not part of synthesized ASIC RTL.

It observes `pwm_i` for a programmable number of clock cycles.

During the observation window it counts:

```text
total samples
HIGH PWM samples
```

At the end of the window it calculates:

```text
duty_permille = HIGH_samples x 1000 / total_samples
```

For a 30% PWM duty cycle:

```text
300 permille = 30%
```

The model asserts `sample_valid_o` whenever a new measurement is ready.

This verifies that the actual PWM waveform matches the software-programmed period/duty settings.

---

# 27. UART Transmitter: `uart_tx.sv`

The UART transmitter sends one standard 8N1 frame.

The interface includes:

```text
baud_div_i
start_i
data_i[7:0]
tx_o
busy_o
done_o
```

## 27.1 Frame format

```text
Idle = 1
Start bit = 0
8 data bits, LSB first
No parity
Stop bit = 1
```

Conceptually:

```text
Idle  Start   D0 D1 D2 D3 D4 D5 D6 D7   Stop   Idle
  1     0      x  x  x  x  x  x  x  x     1      1
```

The transmitter constructs a 10-bit frame:

```text
{stop_bit, data[7:0], start_bit}
```

and sends one bit every `baud_div` system-clock cycles.

To avoid invalid operation, values below 2 are internally clamped to 2.

## 27.2 Busy and done

When `start_i` is accepted:

```text
busy_o = 1
```

After the stop bit completes:

```text
busy_o = 0
done_o = 1 for one clock
```

---

# 28. UART Receiver: `uart_rx.sv`

The UART receiver implements an 8N1 receiver and includes input synchronization.

Its FSM contains:

```text
ST_IDLE
ST_START
ST_DATA
ST_STOP
```

## 28.1 RX synchronizer

`uart_rx_i` is asynchronous to the SoC clock.

The receiver therefore uses two flip-flops:

```text
rx_i
 |
 v
rx_meta_q
 |
 v
rx_sync_q
```

This reduces metastability propagation into the UART state machine.

## 28.2 Start-bit detection

In `ST_IDLE`, the receiver waits for the synchronized line to go LOW.

It then waits approximately half of one baud interval and rechecks the signal.

If it is still LOW, the start bit is accepted.

This samples near the center of the start bit rather than treating a short glitch as a valid frame.

## 28.3 Data sampling

Eight bits are sampled at one full baud interval each.

They are captured LSB-first into the receive shift register.

## 28.4 Stop-bit check

After eight bits, the receiver samples the stop bit.

If the line is HIGH:

```text
valid_o = 1
framing_error_o = 0
```

If the stop bit is LOW:

```text
valid_o = 1
framing_error_o = 1
```

The receiver guarantees a minimum effective baud divisor of 4 so that half-bit sampling is meaningful.

---

# 29. UART Memory-Mapped Peripheral: `uart_peripheral.sv`

This block combines:

```text
uart_tx
uart_rx
```

with CPU-visible registers and status/error handling.

Base address:

```text
0x4000_1000
```

## 29.1 UART register map

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x000` | TXDATA | Write | low byte starts UART transmission if TX is idle |
| `0x004` | RXDATA | Read | received byte; reading consumes RX-valid state |
| `0x008` | STATUS | R/W1C | live and sticky status/error bits |
| `0x00C` | BAUD | R/W | clocks per UART bit |

## 29.2 UART STATUS bits

| Bit | Name | Type | Meaning |
|---:|---|---|---|
| 0 | TX busy | live | transmitter is currently sending a frame |
| 1 | RX valid | latched | an unread received byte is available |
| 2 | RX framing error | sticky, W1C | invalid stop bit was detected |
| 3 | RX overrun | sticky, W1C | a new byte arrived before previous RXDATA was consumed |
| 4 | TX busy write error | sticky, W1C | software attempted TXDATA write while transmitter was busy |
| 5 | TX done | sticky, W1C | last accepted transmission completed |

`W1C` means **write one to clear**.

## 29.3 TX behavior

A write to TXDATA uses the low byte when byte strobe 0 is active.

If TX is idle:

```text
tx_data_q = written byte
start pulse = 1
tx_done = cleared
```

If TX is already busy:

```text
transmission is not restarted
TX busy write error = 1
```

## 29.4 RX behavior

When the receiver produces a new byte:

```text
rx_data_q = new byte
rx_valid_q = 1
```

Reading RXDATA clears `rx_valid_q`.

If another byte arrives while an unread byte is still valid, the overrun flag is set. The newest byte is latched.

## 29.5 Framing error

If UART RX detects an invalid stop bit, the framing-error status flag becomes sticky until software clears it by writing one to STATUS bit 2.

## 29.6 Baud divider

The BAUD register stores the number of system clock cycles per UART bit.

Approximate baud rate:

```text
baud = system_clock_frequency / baud_divider
```

For the ASIC top default:

```text
System clock = 50 MHz
Baud divider = 434
```

which is approximately 115.2 kbaud.

Simulation testbenches may override this divider with smaller values so tests complete faster.

---

# 30. UART Terminal Model: `uart_terminal_model.sv`

The UART Terminal Model is testbench-only.

It observes the SoC UART TX line and reuses the same UART receiver logic to decode transmitted bytes.

It provides:

```text
last_byte_o
byte_valid_o
framing_error_o
```

The full-SoC test uses this model to confirm that the processor really transmits:

```text
0x48 = ASCII 'H'
```

on the serial wire, rather than only checking an internal register write.

---

# 31. SPI Master: `spi_master.sv`

The SPI master implements an 8-bit, MSB-first, **SPI Mode 0** transaction.

Mode 0 means:

```text
CPOL = 0
CPHA = 0
```

Therefore:

- SCLK idles LOW.
- MISO is sampled on the rising edge.
- MOSI is updated for the next bit on the falling edge.

The interface includes:

```text
clk_div_i
start_i
tx_data_i[7:0]
rx_data_o[7:0]
busy_o
done_o
sclk_o
mosi_o
miso_i
cs_n_o
```

## 31.1 Start sequence

When idle:

```text
SCLK = 0
CS_N = 1
```

When `start_i` is accepted:

```text
busy = 1
CS_N = 0
MOSI = tx_data[7]
```

The master sends the MSB first.

## 31.2 Rising SCLK edge

On each internally generated rising SCLK transition:

```text
sample MISO
shift into RX register
```

## 31.3 Falling SCLK edge

On each falling transition:

```text
advance bit index
update MOSI for next bit
```

After bit 7 completes:

```text
busy = 0
CS_N = 1
rx_data_o = received byte
done_o = one-clock pulse
```

## 31.4 SPI clock divisor

`clk_div_i` represents the number of system-clock cycles in one SPI **half period**.

Therefore:

```text
SPI frequency ≈ system clock / (2 x clk_div)
```

At 50 MHz with the ASIC-top default divider of 25:

```text
SPI SCLK ≈ 1 MHz
```

Simulation tests may override the divider with a smaller value for speed.

## 31.5 Clock-domain note

SCLK is generated as an output register from the main `clk_i` domain. Internal logic is **not** clocked by `spi_sclk_o`.

Therefore the RTL remains a single internal system-clock domain, which is beneficial for synthesis and physical design.

---

# 32. SPI Memory-Mapped Peripheral: `spi_peripheral.sv`

The SPI peripheral wraps the SPI master with CPU-visible registers.

Base address:

```text
0x4000_2000
```

## 32.1 SPI register map

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x000` | TXDATA | R/W | low byte contains transmit data |
| `0x004` | CTRL | Write | bit 0 = START |
| `0x008` | STATUS | R/W1C | busy, done, start-while-busy error |
| `0x00C` | RXDATA | Read | last received SPI byte |
| `0x010` | CLKDIV | R/W | system clocks per SPI half period |

## 32.2 STATUS bits

| Bit | Meaning |
|---:|---|
| 0 | SPI busy |
| 1 | SPI done, sticky W1C |
| 2 | start attempted while busy, sticky W1C |

## 32.3 Start behavior

Software writes TXDATA and then writes:

```text
CTRL.bit0 = 1
```

If the SPI engine is idle:

```text
start pulse = 1
done flag = cleared
```

If already busy:

```text
start is rejected
start_busy_error = 1
```

When the transfer completes:

```text
rx_data_q = received byte
done_q = 1
```

---

# 33. SPI Slave Model: `spi_slave_model.sv`

The SPI slave model is testbench-only.

It is configured for Mode 0 and normally returns:

```text
0x3C
```

During a transaction it:

- Presents response bits on MISO.
- Captures MOSI on rising SCLK edges.
- Reconstructs the byte transmitted by the SoC.
- Asserts `rx_valid_o` when eight bits have been received.

The full-SoC test therefore verifies both directions:

```text
Master TX = 0xA5
Slave RX  = 0xA5

Slave TX  = 0x3C
Master RX = 0x3C
```

---

# 34. Configuration Memory Contents

The demo firmware expects the first four configuration words to contain:

| Word | Address | Value | Meaning |
|---:|---:|---:|---|
| CFG[0] | `0x2000_0000` | `100` | PWM period |
| CFG[1] | `0x2000_0004` | `30` | PWM duty |
| CFG[2] | `0x2000_0008` | `0x48` | UART transmit byte (`'H'`) |
| CFG[3] | `0x2000_000C` | `0xA5` | SPI transmit byte |

This demonstrates that system behavior is configured through memory rather than hard-coding all demo values directly into the CPU.

---

# 35. Demo Firmware: `firmware/soc_demo.S`

The demo software is a short RV32I program stored in Instruction Memory.

Its complete logical sequence is described below.

## 35.1 Load Configuration SRAM base

```asm
lui x10, 0x20000
```

Result:

```text
x10 = 0x2000_0000 = CFG_BASE
```

## 35.2 Read PWM configuration

```asm
lw x1, 0(x10)
lw x2, 4(x10)
```

Result:

```text
x1 = 100  -> period
x2 = 30   -> duty
```

## 35.3 Configure PWM

```asm
lui  x11, 0x40000
addi x3, x0, 1
sw   x3, 0(x11)
sw   x1, 4(x11)
sw   x2, 8(x11)
```

Result:

```text
PWM enable = 1
PWM period = 100
PWM duty   = 30
```

The PWM block then generates a 30% duty-cycle waveform.

## 35.4 Load and transmit UART byte

```asm
lui x12, 0x40001
lw  x4, 8(x10)
sw  x4, 0(x12)
```

Result:

```text
x12 = UART_BASE
x4  = 0x48
TXDATA write starts transmission of ASCII 'H'
```

## 35.5 Load SPI transmit byte

```asm
lui x13, 0x40002
lw  x5, 12(x10)
sw  x5, 0(x13)
```

Result:

```text
x13 = SPI_BASE
x5  = 0xA5
SPI TXDATA = 0xA5
```

## 35.6 Start SPI transfer

```asm
addi x6, x0, 1
sw   x6, 4(x13)
```

This writes START bit 0 in the SPI CTRL register.

## 35.7 Poll SPI completion

```asm
spi_wait:
lw   x7, 8(x13)
andi x7, x7, 2
beq  x7, x0, spi_wait
```

STATUS bit 1 is the SPI done flag.

Software repeatedly reads the status register until completion.

This demonstrates real software polling of a hardware peripheral.

## 35.8 Read SPI response

```asm
lw x8, 12(x13)
```

The testbench SPI slave returns:

```text
0x3C
```

so:

```text
x8 = 0x0000003C
```

## 35.9 Store SPI response in Data SRAM

```asm
lui x14, 0x10000
sw  x8, 0(x14)
```

Result:

```text
DMEM[0] = 0x0000003C
```

## 35.10 Poll UART RX-valid

```asm
uart_wait:
lw   x9, 8(x12)
andi x9, x9, 2
beq  x9, x0, uart_wait
```

UART STATUS bit 1 indicates that a received byte is available.

## 35.11 Read UART RX byte

```asm
lw x15, 4(x12)
```

The full-SoC test drives:

```text
0x5A
```

into UART RX.

Reading RXDATA also consumes/clears the RX-valid state.

## 35.12 Store UART response in Data SRAM

```asm
sw x15, 4(x14)
```

Result:

```text
DMEM[1] = 0x0000005A
```

## 35.13 Final software loop

```asm
forever:
jal x0, forever
```

The CPU remains active in a legal infinite loop rather than intentionally trapping.

---

# 36. End-to-End Demo Sequence

The entire demonstration can be summarized as:

```text
RESET
  |
  v
PC = 0x00000000
  |
  v
Fetch firmware from IMEM
  |
  v
Read Config SRAM
  |
  +---- CFG[0] = 100 ------------------+
  |                                     |
  +---- CFG[1] = 30 -------------------+|
  |                                    ||
  +---- CFG[2] = 0x48 ----------------+||
  |                                   |||
  +---- CFG[3] = 0xA5 ---------------+|||
                                      ||||
                                      vvvv
                          +---------------------------+
                          | Software configures HW    |
                          +-------------+-------------+
                                        |
             +--------------------------+--------------------------+
             |                          |                          |
             v                          v                          v
        PWM enable/period/duty      UART TXDATA                SPI TXDATA
        100 / 30                    0x48 ('H')                 0xA5
             |                          |                          |
             v                          v                          v
       PWM waveform               Serial frame             SPI transfer
             |                          |                          |
             v                          v                          v
      Virtual fan = 30%         Terminal sees 'H'       Slave sees 0xA5
                                                               |
                                                               v
                                                        Slave returns 0x3C
                                                               |
                                                               v
                                                        CPU reads RXDATA
                                                               |
                                                               v
                                                        DMEM[0] = 0x3C

External UART stream sends 0x5A
             |
             v
        UART receiver
             |
             v
        STATUS RX-valid
             |
             v
         CPU reads byte
             |
             v
        DMEM[1] = 0x5A
             |
             v
       Infinite JAL loop
```

---

# 37. Full SoC Module: `riscv_fan_soc.sv`

This module is the main integration layer below the ASIC top.

It instantiates:

```text
rv32i_core
imem_ip_wrapper
mmio_decoder
dmem_ip_wrapper
config_ip_wrapper
pwm_peripheral
uart_peripheral
spi_peripheral
```

It also implements the transaction-target tracking described earlier.

## 37.1 Main external signals

```text
clk_i
rst_i
pwm_o
uart_tx_o
uart_rx_i
spi_sclk_o
spi_mosi_o
spi_miso_i
spi_cs_n_o
```

## 37.2 Debug outputs

```text
debug_pc_o
debug_instr_o
debug_halted_o
debug_trap_o
debug_trap_cause_o
debug_state_o
```

These make CPU state visible during simulation and debug.

---

# 38. ASIC Top Level: `riscv_fan_soc_asic_top.sv`

The intended synthesis top is:

```text
riscv_fan_soc_asic_top
```

This is different from the older FPGA top.

External ports are:

```text
clk_i
reset_n_i
pwm_o
uart_tx_o
uart_rx_i
spi_sclk_o
spi_mosi_o
spi_miso_i
spi_cs_n_o
status_halted_o
status_trap_o
debug_pc_o
debug_instr_o
debug_trap_cause_o
debug_state_o
```

These debug ports are real top-level outputs (not internal-only nets) so the
CPU debug bus stays reachable and Genus cannot delete the logic that drives
it as unobservable/unloaded.

## 38.1 Reset synchronizer

The ASIC top accepts active-low external reset:

```text
reset_n_i
```

and uses a two-bit reset synchronizer for:

```text
asynchronous assertion
synchronous deassertion
```

Conceptually:

```text
reset_n_i
    |
    v
2-stage reset release synchronizer
    |
    v
internal active-high rst_i
    |
    v
SoC
```

This means reset can be asserted immediately, but release is aligned with the system clock.

## 38.2 Final hardware defaults

The ASIC top currently selects:

```text
IMEM = 256 x 32
DMEM = 256 x 32
CFG  = 256 x 32

PWM default period    = 100
UART default baud div = 434
SPI default clock div = 25
```

Simulation testbenches are free to override divisors or memory depths to reduce runtime, but the final ASIC top captures the intended hardware configuration.

## 38.3 Future ASIC integration note

The current top is the **digital logic top**. During a full tapeout-oriented flow, technology-specific I/O cells, power/ground strategy, filler/endcap/tap cells, ESD/pad-ring integration, and package constraints may be added by the ASIC flow or by a higher-level chip wrapper depending on the chosen PDK and course flow.

---

# 39. Clocking Strategy

The internal SoC uses one primary system clock:

```text
clk_i
```

The CPU, memories, PWM, UART, SPI control logic, and interconnect all operate from this system clock.

UART timing is produced using counters.

SPI SCLK is generated as an output signal using counters but is **not** used as a separate internal clock domain.

PWM is also generated using a counter rather than creating a new clock domain.

This single-clock-domain structure simplifies:

- Static timing analysis
- Clock-tree synthesis
- CDC analysis
- Physical implementation

The only explicit asynchronous functional input is UART RX, which is synchronized internally.

SPI MISO is sampled by logic operating on `clk_i` at controlled points in the SPI state operation. External SPI I/O timing must be constrained later based on the actual attached device timing.

---

# 40. RTL Simulation vs Real ASIC Boot/Initialization

During RTL simulation, Instruction Memory and Config Memory can be initialized from HEX files.

For example:

```text
firmware/soc_demo.hex
firmware/config_demo.hex
```

This is valid for simulation.

However, ordinary SRAM in fabricated silicon does **not** automatically power up from `$readmemh` or a Quartus MIF file.

Therefore final hardware must use one of the following strategies depending on project requirements:

- ROM macro for fixed program code
- SRAM loaded by a boot ROM
- UART bootloader
- SPI bootloader
- JTAG/debug loading
- External initialization logic

For an academic physical-design exercise, the memory macros may be treated as logical/physical macros without implementing a complete production boot architecture, provided that this limitation is documented.

---

# 41. Verification Environment

Verification is performed in layers so that failures can be isolated easily.

The environment is written in SystemVerilog and uses directed self-checking testbenches.

A testbench prints:

```text
[PASS]
```

when expected behavior is observed and stops with an error/fatal message when a check fails.

---

# 42. Core Unit Testbenches

## `tb_alu.sv`

Checks representative ALU operations.

## `tb_regfile.sv`

Checks:

- Register write/read
- `x0` behavior
- Reset behavior

## `tb_imm_gen.sv`

Checks immediate extraction and sign extension.

## `tb_branch_unit.sv`

Checks all signed/unsigned branch comparisons.

## `tb_lsu.sv`

Checks:

- Byte/halfword/word alignment
- Store byte strobes
- Store data placement
- Sign-extended loads
- Zero-extended loads

## `tb_decoder.sv`

Checks instruction decoding and illegal-encoding handling.

---

# 43. CPU-Level Testbenches

## `tb_rv32i_core.sv`

Checks functional instruction execution including representative:

```text
R-type
Load
Store
Branch
```

## `tb_rv32i_core_multicycle.sv`

Checks:

- FSM sequencing
- Request/ready protocol
- Multicycle behavior

## `tb_core_faults.sv`

Checks exception causes including:

```text
Illegal instruction
Misaligned LW
Misaligned SW
Misaligned JALR
Instruction access fault
Load access fault
Store access fault
ECALL
EBREAK
```

## `tb_core_cycle_count.sv`

Checks exact state/cycle counts for representative instruction classes.

---

# 44. Memory Verification

## `tb_sram_ip_wrappers.sv`

Despite the historical filename, this now validates the ASIC-neutral wrappers/backends.

It checks:

```text
IMEM
DMEM
Config memory
request/ready timing
reads
writes
byte masks
fault behavior
```

Legacy behavioral-memory testbenches may remain in the repository for reference, but the active ASIC-oriented compile path uses the new wrapper/backend architecture.

---

# 45. Peripheral Unit Testbenches

## `tb_pwm.sv`

Checks PWM register programming and generated waveform.

## `tb_uart_tx.sv`

Checks complete serial transmission.

## `tb_uart_rx.sv`

Checks complete serial reception and framing behavior.

## `tb_uart_peripheral.sv`

Checks UART MMIO registers and status/error behavior.

## `tb_spi_master.sv`

Checks Mode-0 master transfer behavior against the SPI slave model.

## `tb_spi_peripheral.sv`

Checks SPI memory-mapped registers, start, completion, and RX/TX behavior.

---

# 46. Integration Testbenches

## `tb_mmio_decoder.sv`

Checks correct selection of:

```text
DMEM
CFG
PWM
UART
SPI
```

and fault generation for invalid addresses.

## `tb_cpu_memory.sv`

Runs real CPU instructions against memory.

Verified examples include:

```text
SW  -> Data SRAM write
LW  -> register load
SB  -> byte-lane write
LBU -> zero-extended byte load
```

## `tb_cpu_pwm.sv`

Runs firmware that programs the PWM peripheral through CPU MMIO writes and verifies the output duty cycle.

## `tb_cpu_uart.sv`

Runs CPU code that performs UART communication and verifies the actual serial byte.

## `tb_cpu_spi.sv`

Runs CPU code that performs a full SPI transfer and stores received data in Data SRAM.

## `tb_error_status.sv`

Checks peripheral sticky status/error mechanisms.

## `tb_soc.sv`

This is the complete end-to-end system test.

It combines:

```text
CPU
Instruction memory
Data SRAM
Config SRAM
PWM
Virtual fan
UART TX/RX
UART terminal
SPI master
SPI slave
Demo firmware
```

---

# 47. Full SoC Verification Result

The final full-system behavior has been verified as:

```text
CFG PWM period   : 100
CFG PWM duty     : 30
PWM output       : 100/30 = 30%
Virtual fan duty : 300 permille
UART TX          : 0x48 ('H')
UART RX          : 0x5A
SPI TX           : 0xA5
SPI RX           : 0x3C
```

The full SoC test reports:

```text
[PASS] tb_soc
```

The compile stage completes with:

```text
Errors   : 0
Warnings : 0
```

A ModelSim Intel Edition message such as:

```text
No extended dataflow license exists
```

is a simulator licensing warning and is not an RTL functional failure.

---

# 48. ModelSim / QuestaSim Simulation Flow

Run all commands from the project root.

## 48.1 Compile everything

```tcl
do sim/compile_all.do
```

This recreates the `work` library and compiles:

- RTL
- ASIC-neutral simulation memory backends
- External simulation models
- All active testbenches

The active ASIC-oriented compile flow does **not** require Intel Quartus RAM IP.

## 48.2 Full regression

```tcl
do sim/run_all.do
```

This runs the complete active regression.

The cycle-count testbench is compiled. If the current `run_all.do` version does not yet invoke it, add it to the regression section so its `[PASS]` result is also included in the final transcript.

## 48.3 Full SoC waveform GUI

```tcl
do sim/run_soc_gui.do
```

This opens the full SoC test and adds useful wave groups for:

```text
Clock/reset
CPU state
PC/instruction
Instruction-memory handshake
Data/MMIO bus
MMIO decoder
Outstanding target
Data SRAM
Config SRAM
PWM/virtual fan
UART
SPI
Core internal registers
```

---

# 49. Recommended Waveform Signals

For CPU execution, inspect:

```text
state
pc
instr
halted
trap
cause
```

For Instruction Memory:

```text
imem_req
imem_ready
imem_fault
imem_addr
imem_rdata
```

For Data/MMIO transactions:

```text
cpu_req
cpu_write
cpu_ready
cpu_fault
cpu_addr
cpu_wdata
cpu_rdata
cpu_wstrb
```

For decode routing:

```text
sel_dmem
sel_cfg
sel_pwm
sel_uart
sel_spi
decode_fault
```

For PWM:

```text
enable_q
period_q
duty_q
counter_q
pwm_o
fan_duty_permille
```

For UART:

```text
uart_tx
uart_rx
tx_data_q
rx_data_q
rx_valid_q
framing_error_q
```

For SPI:

```text
spi_cs_n
spi_sclk
spi_mosi
spi_miso
tx_data_q
rx_data_q
busy
done
```

---

# 50. Project Directory Structure

A simplified structure is:

```text
riscv_fan_soc_multicycle_ip_v1/
|
+-- rtl/
|   |
|   +-- common/
|   |   +-- soc_pkg.sv
|   |
|   +-- core/
|   |   +-- rv32i_alu.sv
|   |   +-- rv32i_regfile.sv
|   |   +-- rv32i_imm_gen.sv
|   |   +-- rv32i_decoder.sv
|   |   +-- rv32i_branch_unit.sv
|   |   +-- rv32i_lsu.sv
|   |   +-- rv32i_core.sv
|   |
|   +-- memory_ip/
|   |   +-- imem_ip_wrapper.sv
|   |   +-- dmem_ip_wrapper.sv
|   |   +-- config_ip_wrapper.sv
|   |
|   +-- memory_asic/
|   |   +-- asic_imem.sv
|   |   +-- asic_dmem.sv
|   |   +-- asic_config_mem.sv
|   |
|   +-- memory_macro/
|   |   +-- asic_sram_macro_stubs.sv
|   |
|   +-- periph/
|   |   +-- pwm_peripheral.sv
|   |   +-- uart_tx.sv
|   |   +-- uart_rx.sv
|   |   +-- uart_peripheral.sv
|   |   +-- spi_master.sv
|   |   +-- spi_peripheral.sv
|   |
|   +-- soc/
|       +-- mmio_decoder.sv
|       +-- riscv_fan_soc.sv
|       +-- riscv_fan_soc_asic_top.sv
|       +-- riscv_fan_soc_fpga_top.sv     # legacy FPGA path only
|
+-- tb/
|   +-- core/
|   +-- memory/
|   +-- periph/
|   +-- integration/
|   +-- models/
|
+-- firmware/
|   +-- soc_demo.S
|   +-- soc_demo.hex
|   +-- config_demo.hex
|   +-- build_firmware.py
|
+-- sim/
|   +-- filelist.f
|   +-- filelist_rtl.f
|   +-- compile_all.do
|   +-- run_all.do
|   +-- run_soc_gui.do
|   +-- tests/
|
+-- asic/
|   +-- filelist_asic.f
|   +-- riscv_fan_soc_asic.sdc
|
+-- quartus/                             # legacy/reference FPGA flow
|   +-- ip/
|   +-- *.qsf / *.qpf / *.sdc
|
+-- docs/
+-- tools/
+-- README.md
```

---

# 51. Files Used in Active ASIC-Oriented RTL Simulation

The active simulation file list includes:

```text
soc_pkg
CPU core components
ASIC-neutral memory backends
memory wrappers
PWM/UART/SPI
MMIO decoder
SoC
ASIC top
simulation models
```

The active path does not require:

```text
quartus/ip/imem_ip.v
quartus/ip/dmem_ip.v
quartus/ip/cfg_ip.v
.qip files
tb/models_ip/intel_ram_ip_sim_models.sv
```

Those may stay in the repository as historical FPGA artifacts.

---

# 52. ASIC Synthesis Preparation

After RTL functional verification, the next implementation step is **logic synthesis**.

The intended Cadence flow is:

```text
Verified RTL
    |
    v
Cadence Genus
Logic Synthesis
    |
    v
Technology-mapped gate netlist
    |
    v
Equivalence checking
    |
    v
Cadence Innovus
Physical Design
```

The synthesis top is:

```text
riscv_fan_soc_asic_top
```

The ASIC source list is:

```text
asic/filelist_asic.f
```

---

# 53. ASIC Synthesis Memory Mode

During ASIC synthesis, define:

```text
ASIC_USE_SRAM_MACROS
```

This selects the macro branches in:

```text
asic_imem
asic_dmem
asic_config_mem
```

and prevents behavioral simulation arrays from becoming large collections of standard-cell flip-flops and muxes.

The real SRAM/ROM macro must later match or be adapted to the expected interface.

---

# 54. Initial ASIC Timing Constraint

The current SDC creates a 50-MHz system clock:

```tcl
create_clock -name clk_i -period 20.000 [get_ports clk_i]
```

Therefore:

```text
Clock period = 20 ns
Frequency    = 50 MHz
```

The SDC also treats:

```text
reset_n_i
```

as an asynchronous reset source rather than a normal data path.

UART RX is also marked as asynchronous at the primary input because synchronization is performed internally.

SPI input/output delays are not guessed yet. They must be added later when the external SPI device timing requirements are known.

---

# 55. Important Timing Note: Multicycle CPU vs `set_multicycle_path`

The processor is architecturally multicycle, but that does **not** mean all paths should be given an SDC multicycle exception.

The CPU already breaks instruction work into separate clocked states and registers.

Therefore normal register-to-register timing still needs to meet one clock period.

Do not blindly add:

```tcl
set_multicycle_path
```

just because the architecture is called multicycle.

An SDC multicycle exception should only be applied to a path if the hardware timing relationship is specifically designed and verified for that exception.

---

# 56. Cadence ASIC Flow After RTL Freeze

The intended backend sequence is:

```text
RTL Functional Verification
          |
          v
RTL Freeze
          |
          v
Cadence Genus Logic Synthesis
          |
          +--> Read standard-cell .lib
          +--> Read SRAM macro .lib
          +--> Read RTL
          +--> Elaborate top
          +--> Apply SDC
          +--> Generic synthesis
          +--> Technology mapping
          +--> Timing/area/power reports
          |
          v
Synthesized Netlist
          |
          v
Cadence Conformal Equivalence Check
          |
          v
Cadence Innovus Design Import
          |
          v
Floorplanning
          |
          v
SRAM Macro Placement
          |
          v
Power Planning
          |
          v
Standard-Cell Placement
          |
          v
Pre-CTS Optimization
          |
          v
Clock Tree Synthesis
          |
          v
Post-CTS Optimization
          |
          v
Routing
          |
          v
Post-Route Optimization
          |
          v
Parasitic Extraction
          |
          v
Static Timing / Power / Physical Signoff
          |
          v
GDS
```

---

# 57. Inputs Required Before Meaningful Cadence Synthesis

Before final Genus synthesis, the following project-specific technology information is required:

```text
Target PDK / technology node
Standard-cell Liberty library
Standard-cell LEF
Technology LEF
Operating voltage and corners
Real SRAM/ROM macro names
SRAM macro Liberty files
SRAM macro LEF files
Target clock period
External I/O timing assumptions
```

Without the technology library, RTL can be elaborated and structurally checked, but meaningful technology-mapped timing/area results cannot be finalized.

---

# 58. Physical Design Inputs for Innovus

Innovus will eventually require:

```text
Synthesized Verilog netlist
SDC / MMMC constraints
Technology LEF
Standard-cell LEF
SRAM macro LEF
Timing libraries
RC/QRC technology information
Power/ground net definitions
```

For final layout/signoff, additional views may include:

```text
GDS
CDL/SPICE
DRC deck
LVS deck
antenna rules
metal fill rules
```

The exact set depends on the PDK and academic lab environment.

---

# 59. Current RTL Completion Status

The RTL design phase currently covers:

```text
[Done] RV32I multicycle CPU architecture
[Done] ALU
[Done] Register File
[Done] Immediate Generator
[Done] Decoder
[Done] Branch Unit
[Done] LSU
[Done] Instruction fetch interface
[Done] Data/MMIO interface
[Done] Trap/exception handling
[Done] Instruction memory wrapper
[Done] Data SRAM wrapper
[Done] Config SRAM wrapper
[Done] ASIC-neutral memory abstraction
[Done] MMIO decoder
[Done] PWM peripheral
[Done] UART TX
[Done] UART RX
[Done] UART peripheral
[Done] SPI master
[Done] SPI peripheral
[Done] Virtual fan model
[Done] UART terminal model
[Done] SPI slave model
[Done] Demo firmware
[Done] Unit verification
[Done] Integration verification
[Done] Full-SoC verification
[Done] ASIC digital top
[Done] Initial ASIC file list
[Done] Initial ASIC SDC
```

The next project phase is not new functional RTL development. It is **ASIC implementation**, beginning with technology setup and logic synthesis in Cadence Genus.

Small RTL edits may still be required later only if synthesis, lint, equivalence, or physical-design checks reveal an implementation issue.

---

# 60. Final Demonstrated Results

The verified end-to-end demo is:

```text
Processor              : 32-bit RV32I multicycle
Instruction Memory     : 1 KiB default (256 x 32)
Data SRAM              : 1 KiB default (256 x 32)
Configuration SRAM     : 1 KiB default (256 x 32)

PWM period             : 100 system-clock cycles
PWM duty               : 30 system-clock cycles
PWM duty percentage    : 30%
Virtual fan measurement: 300 permille

UART TX                : 0x48 = ASCII 'H'
UART RX                : 0x5A

SPI Master TX          : 0xA5
SPI Slave RX           : 0xA5
SPI Slave response     : 0x3C
SPI Master RX          : 0x3C

DMEM[0] after SPI      : 0x0000003C
DMEM[1] after UART RX  : 0x0000005A

Baseline full SoC test : PASS before final 256x32 normalization
Final package status   : rerun do sim/run_all.do after copying these edits
```

---

# 61. Summary of What Each Major Component Does

| Component | Main Responsibility |
|---|---|
| `soc_pkg` | Common addresses, offsets, ALU controls, immediate types, trap causes |
| `rv32i_core` | Multicycle CPU sequencing, PC, instruction execution, trap handling |
| `rv32i_decoder` | Converts RV32I instruction encoding into control signals |
| `rv32i_imm_gen` | Extracts/sign-extends I/S/B/U/J immediates |
| `rv32i_regfile` | Stores x0-x31, two reads + one write |
| `rv32i_alu` | Arithmetic, logical, shift, and compare operations |
| `rv32i_branch_unit` | Evaluates all RV32I conditional branch conditions |
| `rv32i_lsu` | Alignment checking, store masks/data, load extraction/extension |
| `imem_ip_wrapper` | IMEM address validation and synchronous request/ready adaptation |
| `dmem_ip_wrapper` | DMEM range conversion, byte mask forwarding, response/fault handling |
| `config_ip_wrapper` | Configuration memory access and response/fault handling |
| `asic_imem` | Simulation IMEM or ASIC instruction-memory macro interface |
| `asic_dmem` | Simulation Data SRAM or ASIC data-memory macro interface |
| `asic_config_mem` | Simulation Config SRAM or ASIC configuration-memory macro interface |
| `mmio_decoder` | Routes CPU data accesses to memory or the selected peripheral |
| `riscv_fan_soc` | Integrates CPU, memories, MMIO, PWM, UART, SPI and tracks transactions |
| `pwm_peripheral` | Programmable PWM waveform generation |
| `uart_tx` | Serializes one 8N1 UART byte |
| `uart_rx` | Synchronizes and decodes one 8N1 UART byte |
| `uart_peripheral` | UART registers, status, errors, TX/RX control |
| `spi_master` | Performs 8-bit MSB-first Mode-0 SPI transfer |
| `spi_peripheral` | SPI MMIO registers, start/status/error handling |
| `riscv_fan_soc_asic_top` | ASIC-facing top and reset synchronization |
| `virtual_fan_model` | Measures PWM duty for simulation |
| `uart_terminal_model` | Decodes SoC UART TX during simulation |
| `spi_slave_model` | Provides SPI response and checks MOSI during simulation |
| `soc_demo.S` | Software that drives the complete hardware demo |

---

# 62. Conclusion

This project is a complete educational RISC-V SoC that demonstrates the complete path from software instruction execution to hardware peripheral behavior.

The CPU fetches RV32I firmware from Instruction Memory, reads configuration values, programs hardware through memory-mapped registers, controls a PWM output, communicates through UART and SPI, and stores returned communication data in Data SRAM.

The RTL uses a true multicycle FSM and synchronous request/ready memory interfaces. The memory architecture has been separated from Intel FPGA-specific M10K IP and converted to an ASIC-neutral abstraction so that real SRAM/ROM macros can be inserted later without redesigning the processor or peripheral subsystem.

The verification environment checks not only individual modules but also complete firmware-driven system behavior. The current full-system test demonstrates a 30% fan PWM duty, UART transmission of `'H'`, UART reception of `0x5A`, SPI transmission of `0xA5`, SPI reception of `0x3C`, and correct storage of received data in Data SRAM.

At this point the functional RTL phase is complete and the project is ready to proceed to the ASIC backend flow:

```text
Cadence Genus logic synthesis
        ->
Equivalence checking
        ->
Cadence Innovus physical design
        ->
Timing/physical signoff
        ->
Final layout/GDS
```
