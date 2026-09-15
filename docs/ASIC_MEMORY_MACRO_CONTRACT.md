# ASIC Memory Macro Integration Contract

This file defines the **logical interface that the final custom memory macro adapters must preserve**. The CPU and SoC should not be redesigned when the physical macros are introduced.

## Logical memory sizes

| Memory | Logical organization | Byte range | Purpose |
|---|---:|---|---|
| IMEM | 256 x 32 | `0x0000_0000`-`0x0000_03FF` | RV32I instructions |
| DMEM | 256 x 32 | `0x1000_0000`-`0x1000_03FF` | data |
| CONFIG | 256 x 32 | `0x2000_0000`-`0x2000_03FF` | configuration |

All logical macro word addresses are therefore 8 bits.

## Timing contract

The current wrappers assume a **one-cycle synchronous read**:

```text
clock N   : request/address accepted
clock N+1 : ready asserted and read data valid
```

A custom macro with a different read latency requires an adapter/handshake update before integration.

## IMEM logical macro

Required logical signals: clock, chip-select/read-enable, 8-bit word address, and 32-bit read data. IMEM is read-only from the CPU side. A physical SRAM may still be used underneath if its write controls are tied inactive and a valid boot/preload mechanism exists.

## DMEM and CONFIG logical macros

Required logical signals: clock, chip select, write enable, 8-bit word address, 32-bit write data, 32-bit read data, and four byte write enables. Byte write enables are required to preserve RV32I `SB`, `SH`, and `SW` semantics without a read-modify-write controller.

## Banking narrower macros

The CPU interface remains 32-bit. If the custom physical macro is **256 x 16**, use two physical macros in parallel per logical memory:

```text
logical bits [15:0]  -> physical macro lane 0
logical bits [31:16] -> physical macro lane 1
```

That is 2 physical macros per logical memory, 6 total for IMEM + DMEM + CONFIG. If the physical macro is **128 x 16**, both width and depth banking are needed: 4 physical macros per logical memory, 12 total.

A 16-bit physical macro without write masking cannot directly implement an 8-bit `SB`. Prefer a macro with byte-write support (or x8 banks). Otherwise a read-modify-write adapter is required and the current one-cycle write/response contract must be revisited.

**Update (2026-09-15):** This is no longer hypothetical. The project's actual macro is `ram_256x16A` (256 x 16, single-port synchronous, one `WEN` per whole 16-bit half, no byte mask) — see `asic/genus/lib/ram_256x16A_{slow,typical,fast}_syn.lib`. It is banked exactly as described above (2 instances per logical memory, 6 total) in `rtl/memory_macro/asic_sram_macro_stubs.sv`. The `SB` read-modify-write is implemented in `dmem_ip_wrapper.sv` / `config_ip_wrapper.sv`, guarded by `` `ifdef ASIC_USE_SRAM_MACROS ``: a single-byte store now takes 2 cycles (read, then merged full-word write) instead of 1; aligned `SW`/`SH` stores are unaffected. This only changes the ASIC synthesis path — normal ModelSim regression (behavioral memory array, real per-byte writes) keeps its original 1-cycle timing untouched.

Note: `ram_256x16A`'s Liberty files report `nom_voltage : 1.800` (1.8V), while the standard-cell library (`slow_vdd1v0_basicCells.lib`) targets a ~1.0V node. If these are genuinely from different process/voltage domains rather than a deliberate dual-rail (memory-at-1.8V, logic-at-1.0V) design, this needs resolving with the PDK/macro vendor before tapeout — Genus synthesis timing numbers will not be physically meaningful otherwise, and a dual-rail design would need level shifters at the macro boundary, planned in Innovus (UPF/power planning), not in Genus.

## Required technology views

For final implementation, the memory must belong to the **same process/voltage environment** as the standard-cell implementation. Typical integration collateral includes Liberty timing/power (`.lib`), LEF abstract (`.lef`), logical Verilog model (`.v`), GDSII (`.gds`), and where available CDL/SPICE for LVS/circuit verification.

## Power-up / firmware note

The behavioral RTL uses `$readmemh` for verification. Ordinary SRAM is volatile and does not acquire firmware/configuration from a HEX file after fabrication. A real chip therefore needs a ROM or a defined SRAM boot/preload mechanism (for example JTAG, SPI/UART boot, test loading, or another boot source). For an academic place-and-route exercise, a preinitialized-memory assumption may be documented, but it is not a physical SRAM power-up mechanism.
