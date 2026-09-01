# Reference assembly for soc_demo.hex (RV32I only)
# x10 = CFG_BASE  0x20000000
# x11 = PWM_BASE  0x40000000
# x12 = UART_BASE 0x40001000
# x13 = SPI_BASE  0x40002000
# x14 = DMEM_BASE 0x10000000

lui   x10, 0x20000
lw    x1, 0(x10)       # PWM period
lw    x2, 4(x10)       # PWM duty
lui   x11, 0x40000
addi  x3, x0, 1
sw    x3, 0(x11)       # PWM enable
sw    x1, 4(x11)       # period
sw    x2, 8(x11)       # duty

lui   x12, 0x40001
lw    x4, 8(x10)       # UART character
sw    x4, 0(x12)       # TXDATA

lui   x13, 0x40002
lw    x5, 12(x10)      # SPI TX byte
sw    x5, 0(x13)       # TXDATA
addi  x6, x0, 1
sw    x6, 4(x13)       # START
spi_wait:
lw    x7, 8(x13)       # STATUS
andi  x7, x7, 2        # done bit
beq   x7, x0, spi_wait
lw    x8, 12(x13)      # RXDATA

lui   x14, 0x10000
sw    x8, 0(x14)       # save SPI response

uart_wait:
lw    x9, 8(x12)       # STATUS
andi  x9, x9, 2        # rx_valid bit
beq   x9, x0, uart_wait
lw    x15, 4(x12)      # RXDATA
sw    x15, 4(x14)      # save UART response

forever:
jal   x0, forever
