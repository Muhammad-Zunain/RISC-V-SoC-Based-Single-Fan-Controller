# Run from project root: do sim/tests/run_data_sram.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/memory/tb_data_sram.sv
vsim -voptargs=+acc tb_data_sram
add wave -r sim:/tb_data_sram/*
run -all
wave zoom full
