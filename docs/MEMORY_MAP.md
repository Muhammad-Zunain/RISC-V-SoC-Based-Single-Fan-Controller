# Memory and Register Map

All addresses are byte addresses. The CPU is little-endian.

## Global map

| Base | Region |
|---|---|
| `0x0000_0000` | Instruction SRAM |
| `0x1000_0000` | Data SRAM |
| `0x2000_0000` | Configuration SRAM |
| `0x4000_0000` | PWM 4 KiB MMIO page |
| `0x4000_1000` | UART 4 KiB MMIO page |
| `0x4000_2000` | SPI 4 KiB MMIO page |

Memory sizes are parameters. The default SoC configuration is 1024 instruction words, 1024 data words, and 256 configuration words.

## PWM

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x000` | CTRL | R/W | bit 0 = enable |
| `0x004` | PERIOD | R/W | PWM period in system clocks |
| `0x008` | DUTY | R/W | number of high clocks per period |
| `0x00C` | COUNT | R | current counter |

Rules: period 0 forces output low. Duty 0 gives 0%. Duty >= period gives 100% while enabled.

## UART

8 data bits, no parity, 1 stop bit (8N1).

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x000` | TXDATA | W | low byte starts TX if transmitter is idle |
| `0x004` | RXDATA | R | low byte is received data; read consumes RX-valid |
| `0x008` | STATUS | R/W1C | status/error bits |
| `0x00C` | BAUD_DIV | R/W | system clocks per UART bit |

STATUS:

- bit 0: TX busy
- bit 1: RX valid
- bit 2: RX framing error, sticky, W1C
- bit 3: RX overrun, sticky, W1C
- bit 4: TX write attempted while busy, sticky, W1C
- bit 5: TX done, sticky, W1C

## SPI

SPI master is fixed to Mode 0 (`CPOL=0`, `CPHA=0`), 8-bit, MSB first, one active-low chip-select.

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x000` | TXDATA | R/W | low byte to transmit |
| `0x004` | CTRL | W | write bit 0 = 1 to start |
| `0x008` | STATUS | R/W1C | status bits |
| `0x00C` | RXDATA | R | low byte received |
| `0x010` | CLK_DIV | R/W | system clocks per half-SCLK |

STATUS:

- bit 0: busy
- bit 1: done, sticky, W1C by writing bit 1
- bit 2: start requested while busy, sticky, W1C by writing bit 2

## Configuration SRAM demo contents

`firmware/config_demo.hex`:

| Word | Value | Use |
|---|---:|---|
| 0 | 100 | PWM period |
| 1 | 30 | PWM high clocks |
| 2 | `0x48` | UART `H` |
| 3 | `0xA5` | SPI transmit byte |
