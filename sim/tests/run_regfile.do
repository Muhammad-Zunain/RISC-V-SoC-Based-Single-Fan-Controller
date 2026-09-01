# Run from project root: do sim/tests/run_regfile.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_regfile.sv
vsim -voptargs=+acc tb_regfile
add wave -r sim:/tb_regfile/*
run -all
wave zoom full
