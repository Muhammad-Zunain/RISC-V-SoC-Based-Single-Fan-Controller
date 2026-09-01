# Run from project root: do sim/tests/run_branch_unit.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_branch_unit.sv
vsim -voptargs=+acc tb_branch_unit
add wave -r sim:/tb_branch_unit/*
run -all
wave zoom full
