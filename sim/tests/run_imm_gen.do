# Run from project root: do sim/tests/run_imm_gen.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_imm_gen.sv
vsim -voptargs=+acc tb_imm_gen
add wave -r sim:/tb_imm_gen/*
run -all
wave zoom full
