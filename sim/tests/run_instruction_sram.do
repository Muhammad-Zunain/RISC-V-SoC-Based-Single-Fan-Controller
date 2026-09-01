# Run from project root: do sim/tests/run_instruction_sram.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/memory/tb_instruction_sram.sv
vsim -voptargs=+acc tb_instruction_sram
add wave -r sim:/tb_instruction_sram/*
run -all
wave zoom full
