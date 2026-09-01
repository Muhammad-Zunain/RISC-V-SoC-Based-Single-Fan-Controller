# Run from project root: do sim/tests/run_decoder.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/core/tb_decoder.sv
vsim -voptargs=+acc tb_decoder
add wave -r sim:/tb_decoder/*
run -all
wave zoom full
