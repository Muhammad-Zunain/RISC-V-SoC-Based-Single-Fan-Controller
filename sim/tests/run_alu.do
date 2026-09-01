# Run from project root: do sim/tests/run_alu.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv rtl/common/soc_pkg.sv rtl/core/rv32i_alu.sv tb/core/tb_alu.sv
vsim -voptargs=+acc tb_alu
add wave -r sim:/tb_alu/*
run -all
wave zoom full
