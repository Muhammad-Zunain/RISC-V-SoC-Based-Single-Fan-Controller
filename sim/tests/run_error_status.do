# Run from project root: do sim/tests/run_error_status.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/integration/tb_error_status.sv
vsim -voptargs=+acc tb_error_status
add wave -r sim:/tb_error_status/*
run -all
wave zoom full
