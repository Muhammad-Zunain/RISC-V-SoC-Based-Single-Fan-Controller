# ==============================================================
# RISC-V Fan SoC - Base ASIC Timing Constraints
# ============================================================== 

# Main system clock: 50 MHz => 20 ns period
create_clock -name clk_i -period 20.000 [get_ports clk_i]

# External active-low reset is asynchronous at the ASIC boundary.
# Internal reset deassertion is synchronized in riscv_fan_soc_asic_top.
set_false_path -from [get_ports reset_n_i]

# UART RX is asynchronous to clk_i and enters a 2-flop synchronizer.
set_false_path -from [get_ports uart_rx_i]

# SPI input/output delays are intentionally not guessed here.
# Add set_input_delay / set_output_delay after the external SPI
# timing requirements are known.
#
# IMPORTANT:
# The CPU is architecturally multicycle, but do NOT automatically
# use set_multicycle_path. The RTL FSM/register structure already
# partitions operations into clock cycles.
