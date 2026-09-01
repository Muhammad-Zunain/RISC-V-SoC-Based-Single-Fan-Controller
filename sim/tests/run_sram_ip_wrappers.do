quit -sim
if {[file exists work]} {catch {vdel -lib work -all}}
vlib work
vmap work work
vlog -sv tb/models_ip/intel_ram_ip_sim_models.sv rtl/memory_ip/imem_ip_wrapper.sv rtl/memory_ip/dmem_ip_wrapper.sv rtl/memory_ip/config_ip_wrapper.sv tb/memory/tb_sram_ip_wrappers.sv
vsim -voptargs="+acc" tb_sram_ip_wrappers
add wave -r sim:/tb_sram_ip_wrappers/*
run -all
