# ==============================================================
# Complete ModelSim / QuestaSim compilation
#
# Run from PROJECT ROOT:
#
#     do sim/compile_all.do
#
# This compilation uses:
#
#   - Multicycle RV32I core
#   - technology-independent SRAM wrappers
#   - ASIC-neutral synchronous SRAM reference models
#   - PWM / UART / SPI peripherals
#   - Integration testbenches
#
# Intel/Quartus RAM IP is NOT compiled in the ASIC-oriented RTL flow.
#
# ==============================================================

quit -sim

# --------------------------------------------------------------
# Re-create work library
# --------------------------------------------------------------

if {[file exists work]} {
    catch {vdel -lib work -all}
}

vlib work
vmap work work


# --------------------------------------------------------------
# Compile RTL + simulation RAM models + all active testbenches
# --------------------------------------------------------------

vlog -sv +incdir+. -f sim/filelist.f \
    tb/core/tb_alu.sv \
    tb/core/tb_regfile.sv \
    tb/core/tb_imm_gen.sv \
    tb/core/tb_branch_unit.sv \
    tb/core/tb_lsu.sv \
    tb/core/tb_decoder.sv \
    tb/core/tb_rv32i_core.sv \
    tb/core/tb_rv32i_core_multicycle.sv \
    tb/core/tb_core_faults.sv \
    tb/core/tb_core_cycle_count.sv \
    tb/memory/tb_sram_ip_wrappers.sv \
    tb/periph/tb_pwm.sv \
    tb/periph/tb_uart_tx.sv \
    tb/periph/tb_uart_rx.sv \
    tb/periph/tb_uart_peripheral.sv \
    tb/periph/tb_spi_master.sv \
    tb/periph/tb_spi_peripheral.sv \
    tb/integration/tb_mmio_decoder.sv \
    tb/integration/tb_cpu_memory.sv \
    tb/integration/tb_cpu_pwm.sv \
    tb/integration/tb_cpu_uart.sv \
    tb/integration/tb_cpu_spi.sv \
    tb/integration/tb_error_status.sv \
    tb/integration/tb_soc.sv


# --------------------------------------------------------------
# Compilation completed
# --------------------------------------------------------------

echo ""
echo "=================================================="
echo " Compilation completed"
echo " Multicycle RV32I + ASIC-neutral SRAM simulation"
echo "=================================================="
echo ""