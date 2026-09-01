# Base ASIC timing constraints.
# Refine input/output delays after package/interface timing is defined.

create_clock -name clk_i -period 20.000 [get_ports clk_i]

# External asynchronous reset is not a data-timing path.
set_false_path -from [get_ports reset_n_i]

# UART RX is asynchronous to clk_i and is synchronized internally.
# CDC verification should confirm the two-flop synchronizer in uart_rx.sv.
set_false_path -from [get_ports uart_rx_i]

# SPI input/output delays are intentionally not guessed here.
# Add set_input_delay/set_output_delay once external SPI timing is specified.
