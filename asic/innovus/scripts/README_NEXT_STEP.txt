INNOVUS IS THE NEXT STAGE AFTER GENUS.

Do not create the final Innovus import/floorplan scripts until these are known:

- Cadence Innovus version
- PDK / technology node
- Technology LEF
- Standard-cell LEF
- Standard-cell Liberty libraries / MMMC corners
- Real IMEM/DMEM/CFG SRAM LEF + Liberty views
- Power net names (for example VDD/VSS)
- Core utilization target
- I/O / die-size requirement

Inputs from Genus will include:

- riscv_fan_soc_asic_top_syn.v
- riscv_fan_soc_asic_top_syn.sdc

Later Innovus flow:
Design import -> floorplan -> SRAM macro placement -> power planning -> placement -> CTS -> routing -> post-route timing/signoff.
