RISC-V FAN SOC - FIRST CADENCE GENUS RUN
========================================

1. Copy the complete project to the Linux/Cadence machine.

2. Edit ONLY this file first:

   asic/genus/setup_pdk.tcl

   Set:

   STD_CELL_LIB = absolute path to the real standard-cell .lib

   Example only:
   set STD_CELL_LIB "/cad/pdk/.../standard_cells.lib"

3. SRAM_LIBS may remain empty for an initial structural synthesis using
   the existing abstract SRAM black boxes. However, final timing/area
   requires the real SRAM .lib files.

4. From the PROJECT ROOT run:

   genus -files asic/genus/run_genus.tcl

5. Important synthesis top:

   riscv_fan_soc_asic_top

6. Important preprocessor define used automatically by run_genus.tcl:

   ASIC_USE_SRAM_MACROS

7. Expected generated files:

   asic/genus/outputs/riscv_fan_soc_asic_top_syn.v
   asic/genus/outputs/riscv_fan_soc_asic_top_syn.sdc
   asic/genus/outputs/riscv_fan_soc_asic_top_syn.sdf

   asic/genus/reports/check_design_pre.rpt
   asic/genus/reports/check_design_post.rpt
   asic/genus/reports/qor.rpt
   asic/genus/reports/area.rpt
   asic/genus/reports/timing.rpt
   asic/genus/reports/power.rpt

8. Do NOT add any of these to ASIC synthesis:

   tb/
   sim/
   quartus/
   Intel M10K .qip/.v files
   ModelSim behavioral Intel RAM models
   riscv_fan_soc_fpga_top.sv

9. Do NOT start Innovus until Genus synthesis reports have been reviewed.
