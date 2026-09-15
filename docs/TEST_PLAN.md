# Verification Test Plan

## Unit verification

| Testbench | Main checks |
|---|---|
| `tb_alu` | all ALU operations, signed vs unsigned |
| `tb_regfile` | x1/x31 R/W, reset, x0 hardwired zero |
| `tb_imm_gen` | I/S/B/U/J positive and negative immediates |
| `tb_branch_unit` | all six RV32I branch conditions |
| `tb_lsu` | byte/half/word lanes, sign/zero extension, alignment |
| `tb_decoder` | all base instruction classes plus illegal encodings |
| `tb_rv32i_core` | arithmetic, logical, load/store, branch/jump, FENCE, EBREAK |
| `tb_core_faults` | illegal instruction, load alignment/access, control alignment, ECALL |
| `tb_core_cycle_count` | multicycle timing: R-type 5, load 7, store 6, JAL/JALR 4 cycles |
| SRAM tests | preload, word/byte strobes, range behavior |
| `tb_pwm` | disabled, 0%, nominal 30%, 100%, register strobes |
| `tb_uart_tx` | 0x55, 0xA5, H, busy/done, valid frames |
| `tb_uart_rx` | valid data, framing error, false start |
| `tb_uart_peripheral` | MMIO, loopback, busy-write error, W1C status |
| `tb_spi_master` | Mode-0 A5 TX / 3C RX, busy/done/idle |
| `tb_spi_peripheral` | MMIO, clk divider, done/error W1C |
| `tb_mmio_decoder` | DMEM/CFG/PWM/UART/SPI/unmapped decoding |

Active logical memories are IMEM/DMEM/CFG = **256 x 32**. Directed integration tests may instantiate smaller parameter values to reduce simulation runtime; those smaller depths are testbench-local and do not change the ASIC top configuration.

## Subsystem verification

| Testbench | Scenario |
|---|---|
| `tb_cpu_memory` | RV32I SW/LW/SB/LBU through SoC memory map |
| `tb_cpu_pwm` | CPU programs period=100, duty=30 and measured PWM is 30% |
| `tb_cpu_uart` | CPU writes `H`, terminal model decodes `0x48` |
| `tb_cpu_spi` | CPU sends A5, receives 3C, stores response in SRAM |
| `tb_error_status` | UART framing sticky status and SPI start-busy status |

## Full system verification

`tb_soc` loads `soc_demo.hex` and `config_demo.hex`, then checks:

1. CPU configures PWM to period 100 / duty 30.
2. UART terminal receives `H`.
3. SPI slave receives `0xA5` and returns `0x3C`.
4. Testbench sends UART byte `0x5A` back to the SoC.
5. Firmware stores `0x3C` at Data SRAM word 0.
6. Firmware stores `0x5A` at Data SRAM word 1.
7. 1000 sampled PWM clocks contain exactly 300 high samples.
8. Core does not trap during the integrated demo.
