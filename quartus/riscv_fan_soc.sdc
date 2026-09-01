# Default assumes a 50 MHz board clock.
create_clock -name clk_i -period 20.000 [get_ports {clk_i}]
derive_clock_uncertainty
