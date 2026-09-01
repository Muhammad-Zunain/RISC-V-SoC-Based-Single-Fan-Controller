# Run from project root: do sim/tests/run_cpu_spi.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/integration/tb_cpu_spi.sv
vsim -voptargs=+acc tb_cpu_spi
add wave -r sim:/tb_cpu_spi/*
run -all
wave zoom full
