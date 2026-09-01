quit -sim
if {[file exists work]} {catch {vdel -lib work -all}}
vlib work
vmap work work
vlog -sv +incdir+. rtl/common/soc_pkg.sv rtl/core/rv32i_alu.sv rtl/core/rv32i_regfile.sv rtl/core/rv32i_imm_gen.sv rtl/core/rv32i_decoder.sv rtl/core/rv32i_branch_unit.sv rtl/core/rv32i_lsu.sv rtl/core/rv32i_core.sv tb/core/tb_rv32i_core_multicycle.sv
vsim -voptargs="+acc" tb_rv32i_core_multicycle
add wave -r sim:/tb_rv32i_core_multicycle/*
run -all
