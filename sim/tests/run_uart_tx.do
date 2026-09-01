# Run from project root: do sim/tests/run_uart_tx.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/periph/tb_uart_tx.sv
vsim -voptargs=+acc tb_uart_tx
add wave -r sim:/tb_uart_tx/*
run -all
wave zoom full
