# Run from project root: do sim/tests/run_uart_rx.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/periph/tb_uart_rx.sv
vsim -voptargs=+acc tb_uart_rx
add wave -r sim:/tb_uart_rx/*
run -all
wave zoom full
