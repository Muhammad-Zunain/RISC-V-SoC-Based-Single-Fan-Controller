# Run from project root: do sim/tests/run_lsu.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_lsu.sv
vsim -voptargs=+acc tb_lsu
add wave -r sim:/tb_lsu/*
run -all
wave zoom full
