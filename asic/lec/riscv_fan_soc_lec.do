set log file lec.log -replace

read library ../genus/lib/slow_vdd1v0_basicCells.lib -liberty -both

read design lec_defines.vh -verilog -golden
read design ../../rtl/common/soc_pkg.sv -verilog -golden
read design ../../rtl/core/rv32i_alu.sv -verilog -golden
read design ../../rtl/core/rv32i_regfile.sv -verilog -golden
read design ../../rtl/core/rv32i_imm_gen.sv -verilog -golden
read design ../../rtl/core/rv32i_decoder.sv -verilog -golden
read design ../../rtl/core/rv32i_branch_unit.sv -verilog -golden
read design ../../rtl/core/rv32i_lsu.sv -verilog -golden
read design ../../rtl/core/rv32i_core.sv -verilog -golden
read design ../../rtl/memory_macro/asic_sram_macro_stubs.sv -verilog -golden
read design ../../rtl/memory_asic/asic_imem.sv -verilog -golden
read design ../../rtl/memory_asic/asic_dmem.sv -verilog -golden
read design ../../rtl/memory_asic/asic_config_mem.sv -verilog -golden
read design ../../rtl/memory_ip/imem_ip_wrapper.sv -verilog -golden
read design ../../rtl/memory_ip/dmem_ip_wrapper.sv -verilog -golden
read design ../../rtl/memory_ip/config_ip_wrapper.sv -verilog -golden
read design ../../rtl/periph/pwm_peripheral.sv -verilog -golden
read design ../../rtl/periph/uart_tx.sv -verilog -golden
read design ../../rtl/periph/uart_rx.sv -verilog -golden
read design ../../rtl/periph/uart_peripheral.sv -verilog -golden
read design ../../rtl/periph/spi_master.sv -verilog -golden
read design ../../rtl/periph/spi_peripheral.sv -verilog -golden
read design ../../rtl/soc/mmio_decoder.sv -verilog -golden
read design ../../rtl/soc/riscv_fan_soc.sv -verilog -golden
read design ../../rtl/soc/riscv_fan_soc_asic_top.sv -verilog -golden

read design ../genus/outputs/riscv_fan_soc_asic_top_syn.v -verilog -revised

set system mode lec

add compared points -all
compare
