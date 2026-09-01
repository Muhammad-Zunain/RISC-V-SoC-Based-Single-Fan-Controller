# Run from project root: do sim/tests/run_rv32i_core.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_rv32i_core.sv
vsim -voptargs=+acc tb_rv32i_core
add wave -r sim:/tb_rv32i_core/*
run -all
wave zoom full
