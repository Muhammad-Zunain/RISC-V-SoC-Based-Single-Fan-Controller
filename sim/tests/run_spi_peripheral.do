# Run from project root: do sim/tests/run_spi_peripheral.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/periph/tb_spi_peripheral.sv
vsim -voptargs=+acc tb_spi_peripheral
add wave -r sim:/tb_spi_peripheral/*
run -all
wave zoom full
