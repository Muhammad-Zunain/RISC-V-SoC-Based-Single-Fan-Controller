# Run from project root: do sim/tests/run_spi_master.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/periph/tb_spi_master.sv
vsim -voptargs=+acc tb_spi_master
add wave -r sim:/tb_spi_master/*
run -all
wave zoom full
