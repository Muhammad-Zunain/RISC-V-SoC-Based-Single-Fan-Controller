# Run from project root: do sim/tests/run_core_faults.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_core_faults.sv
vsim -voptargs=+acc tb_core_faults
add wave -r sim:/tb_core_faults/*
run -all
wave zoom full
