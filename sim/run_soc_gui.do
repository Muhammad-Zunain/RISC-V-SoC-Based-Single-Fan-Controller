# ==============================================================
# Full SoC GUI Simulation
# RISC-V Fan SoC
# Multicycle RV32I + SRAM IP + PWM + UART + SPI
#
# Run from PROJECT ROOT:
#
#     do sim/run_soc_gui.do
#
# ==============================================================

quit -sim

# --------------------------------------------------------------
# Compile complete project
# --------------------------------------------------------------

do sim/compile_all.do

# --------------------------------------------------------------
# Start Full SoC Testbench
# --------------------------------------------------------------

vsim -voptargs=+acc work.tb_soc

# Log everything for waveform visibility
log -r /*

# Clear existing waveform
delete wave *


# ==============================================================
# CLOCK / RESET
# ==============================================================

add wave -divider "CLOCK / RESET"

add wave sim:/tb_soc/clk
add wave sim:/tb_soc/rst


# ==============================================================
# MULTICYCLE RV32I CORE
# ==============================================================

add wave -divider "MULTICYCLE RV32I CORE"

add wave -radix unsigned     sim:/tb_soc/state
add wave -radix hexadecimal sim:/tb_soc/pc
add wave -radix hexadecimal sim:/tb_soc/instr

add wave sim:/tb_soc/halted
add wave sim:/tb_soc/trap
add wave -radix unsigned sim:/tb_soc/cause


# ==============================================================
# INSTRUCTION SRAM HANDSHAKE
# ==============================================================

add wave -divider "INSTRUCTION SRAM"

add wave sim:/tb_soc/dut/imem_req
add wave sim:/tb_soc/dut/imem_ready
add wave sim:/tb_soc/dut/imem_fault

add wave -radix hexadecimal sim:/tb_soc/dut/imem_addr
add wave -radix hexadecimal sim:/tb_soc/dut/imem_rdata


# ==============================================================
# CPU DATA / MMIO BUS
# ==============================================================

add wave -divider "CPU DATA / MMIO"

add wave sim:/tb_soc/dut/cpu_req
add wave sim:/tb_soc/dut/cpu_write
add wave sim:/tb_soc/dut/cpu_ready
add wave sim:/tb_soc/dut/cpu_fault

add wave -radix hexadecimal sim:/tb_soc/dut/cpu_addr
add wave -radix hexadecimal sim:/tb_soc/dut/cpu_wdata
add wave -radix hexadecimal sim:/tb_soc/dut/cpu_rdata
add wave -radix binary      sim:/tb_soc/dut/cpu_wstrb


# ==============================================================
# MMIO DECODER
# ==============================================================

add wave -divider "MMIO DECODER"

add wave sim:/tb_soc/dut/sel_dmem
add wave sim:/tb_soc/dut/sel_cfg
add wave sim:/tb_soc/dut/sel_pwm
add wave sim:/tb_soc/dut/sel_uart
add wave sim:/tb_soc/dut/sel_spi
add wave sim:/tb_soc/dut/decode_fault


# ==============================================================
# OUTSTANDING TRANSACTION
# ==============================================================

add wave -divider "TRANSACTION CONTROL"

add wave -radix unsigned sim:/tb_soc/dut/target_q
add wave sim:/tb_soc/dut/target_valid_q


# ==============================================================
# DATA SRAM
# ==============================================================

add wave -divider "DATA SRAM"

add wave sim:/tb_soc/dut/dmem_ready
add wave sim:/tb_soc/dut/dmem_fault

add wave -radix hexadecimal sim:/tb_soc/dut/dmem_rdata

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_dmem/ram_addr

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_dmem/ram_q


# ==============================================================
# CONFIG SRAM
# ==============================================================

add wave -divider "CONFIG SRAM"

add wave sim:/tb_soc/dut/cfg_ready
add wave sim:/tb_soc/dut/cfg_fault

add wave -radix hexadecimal sim:/tb_soc/dut/cfg_rdata

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_cfg/ram_addr

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_cfg/ram_q


# ==============================================================
# PWM / FAN
# ==============================================================

add wave -divider "PWM / VIRTUAL FAN"

add wave sim:/tb_soc/pwm

add wave sim:/tb_soc/dut/u_pwm/enable_q

add wave -radix unsigned \
  sim:/tb_soc/dut/u_pwm/period_q

add wave -radix unsigned \
  sim:/tb_soc/dut/u_pwm/duty_q

add wave -radix unsigned \
  sim:/tb_soc/dut/u_pwm/counter_q

add wave sim:/tb_soc/fan_sample_valid

add wave -radix unsigned \
  sim:/tb_soc/fan_duty_permille


# ==============================================================
# UART
# ==============================================================

add wave -divider "UART"

add wave sim:/tb_soc/uart_tx
add wave sim:/tb_soc/uart_rx

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_uart/tx_data_q

add wave -radix hexadecimal \
  sim:/tb_soc/term_byte

add wave sim:/tb_soc/term_valid
add wave sim:/tb_soc/term_frame_error


# ==============================================================
# SPI
# ==============================================================

add wave -divider "SPI"

add wave sim:/tb_soc/csn
add wave sim:/tb_soc/sclk
add wave sim:/tb_soc/mosi
add wave sim:/tb_soc/miso

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_spi/tx_data_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_spi/rx_data_q

add wave -radix hexadecimal \
  sim:/tb_soc/spi_slave_rx

add wave sim:/tb_soc/spi_slave_valid


# ==============================================================
# CORE INTERNAL STATE
# ==============================================================

add wave -divider "CORE INTERNAL"

add wave -radix unsigned \
  sim:/tb_soc/dut/u_core/state_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/pc_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/instr_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/rs1_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/rs2_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/alu_result_q

add wave -radix hexadecimal \
  sim:/tb_soc/dut/u_core/effective_addr_q


# ==============================================================
# RUN
# ==============================================================

run -all

# Zoom complete waveform
wave zoom full