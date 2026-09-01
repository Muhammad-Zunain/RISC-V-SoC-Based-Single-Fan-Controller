# Run from project root: do sim/tests/run_pwm.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/periph/tb_pwm.sv
vsim -voptargs=+acc tb_pwm
add wave -r sim:/tb_pwm/*
run -all
wave zoom full
