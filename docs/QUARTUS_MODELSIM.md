# Quartus and ModelSim/Questa Workflow

## ModelSim / Questa

Always start in the project root directory.

```tcl
do sim/tests/run_alu.do
```

If it passes, continue module-by-module. For the complete regression:

```tcl
do sim/run_all.do
```

For final SoC waveforms:

```tcl
do sim/run_soc_gui.do
```

The testbench is the simulation top. Do **not** synthesize `tb_*` modules.

## Quartus

Open `quartus/riscv_fan_soc.qpf`.

Synthesis top:

```text
riscv_fan_soc_fpga_top
```

Only `rtl/` files belong in synthesis. Testbenches and models are simulation-only.

Run at least:

1. Analysis & Elaboration
2. Analysis & Synthesis
3. Fitter after correct board pin assignments are added
4. Timing Analyzer

The provided SDC assumes 50 MHz.

## Board warning

The supplied project selects Cyclone V `5CSEMA5F31C6` as a useful DE1-SoC-class default but deliberately contains no guessed physical pin locations. Confirm your exact board and merge the vendor pin assignments before programming it.
