# Run from project root: do sim/tests/run_cpu_pwm.do
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -sv +incdir+. -f sim/filelist.f tb/integration/tb_cpu_pwm.sv
vsim -voptargs=+acc tb_cpu_pwm
add wave -r sim:/tb_cpu_pwm/*
run -all
wave zoom full
