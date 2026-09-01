# Run from project root: do sim/tests/run_mmio_decoder.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/integration/tb_mmio_decoder.sv
vsim -voptargs=+acc tb_mmio_decoder
add wave -r sim:/tb_mmio_decoder/*
run -all
wave zoom full
