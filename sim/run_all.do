# ==============================================================
# Complete Regression
# RISC-V Fan SoC - Multicycle + SRAM IP
#
# Run from PROJECT ROOT:
#
#     do sim/run_all.do
#
# ==============================================================

# --------------------------------------------------------------
# Compile everything first
# --------------------------------------------------------------

do sim/compile_all.do


echo ""
echo "=================================================="
echo " Starting Complete Regression"
echo "=================================================="
echo ""


# ==============================================================
# CORE UNIT TESTS
# ==============================================================

echo ""
echo "--------------------------------------------------"
echo " TEST: ALU"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_alu
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: Register File"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_regfile
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: Immediate Generator"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_imm_gen
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: Branch Unit"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_branch_unit
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: LSU"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_lsu
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: Decoder"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_decoder
run -all
quit -sim


# ==============================================================
# MULTICYCLE CPU TESTS
# ==============================================================

echo ""
echo "--------------------------------------------------"
echo " TEST: RV32I Core Functional"
echo " R-Type / Load / Store / Branch"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_rv32i_core
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: RV32I Core Multicycle"
echo " Request / Ready / State Sequencing"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_rv32i_core_multicycle
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: RV32I Core Faults"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_core_faults
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: RV32I Core Cycle Count"
echo " R-type=5 / Load=7 / Store=6 / JAL/JALR=4"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_core_cycle_count
run -all
quit -sim


# ==============================================================
# SRAM IP TEST
# ==============================================================

echo ""
echo "--------------------------------------------------"
echo " TEST: SRAM IP Wrappers"
echo " IMEM / DMEM / CONFIG"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_sram_ip_wrappers
run -all
quit -sim


# ==============================================================
# PERIPHERAL UNIT TESTS
# ==============================================================

echo ""
echo "--------------------------------------------------"
echo " TEST: PWM"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_pwm
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: UART TX"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_uart_tx
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: UART RX"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_uart_rx
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: UART Peripheral"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_uart_peripheral
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: SPI Master"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_spi_master
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: SPI Peripheral"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_spi_peripheral
run -all
quit -sim


# ==============================================================
# SOC / INTEGRATION TESTS
# ==============================================================

echo ""
echo "--------------------------------------------------"
echo " TEST: MMIO Decoder"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_mmio_decoder
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: CPU + Data SRAM"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_cpu_memory
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: CPU + PWM"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_cpu_pwm
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: CPU + UART"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_cpu_uart
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: CPU + SPI"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_cpu_spi
run -all
quit -sim


echo ""
echo "--------------------------------------------------"
echo " TEST: Error / Status"
echo "--------------------------------------------------"

vsim -voptargs=+acc work.tb_error_status
run -all
quit -sim


# ==============================================================
# FULL SOC TEST
# ==============================================================

echo ""
echo "=================================================="
echo " TEST: FULL RISC-V FAN SOC"
echo " CPU + SRAM + PWM + FAN + UART + SPI"
echo "=================================================="

vsim -voptargs=+acc work.tb_soc
run -all
quit -sim


# ==============================================================
# DONE
# ==============================================================

echo ""
echo "=================================================="
echo " COMPLETE REGRESSION FINISHED"
echo { Check transcript above for every [PASS] }
echo "=================================================="
echo ""