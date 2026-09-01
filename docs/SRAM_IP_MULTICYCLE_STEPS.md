# Quartus 18.1 SRAM IP + Multicycle RV32I Conversion

This project version changes only the blocks that must change for synchronous FPGA RAM:

- `rtl/core/rv32i_core.sv` -> multicycle request/wait/writeback FSM
- `rtl/memory_ip/imem_ip_wrapper.sv` -> wrapper around generated `imem_ip`
- `rtl/memory_ip/dmem_ip_wrapper.sv` -> wrapper around generated `dmem_ip`
- `rtl/memory_ip/config_ip_wrapper.sv` -> wrapper around generated `cfg_ip`
- `rtl/soc/riscv_fan_soc.sv` -> request/ready MMIO integration
- `rtl/soc/riscv_fan_soc_fpga_top.sv` -> multicycle top
- `quartus/riscv_fan_soc.qsf` -> uses wrappers instead of behavioral SRAMs

The already verified ALU, register file, immediate generator, decoder, branch unit, LSU, PWM, UART and SPI modules are unchanged.

## IP 1: Instruction SRAM (`imem_ip`)

1. Open `quartus/riscv_fan_soc.qpf` in Quartus Prime 18.1.
2. Open `Tools > IP Catalog`.
3. Search for `RAM: 1-PORT` under On-Chip Memory.
4. Double-click it.
5. Name the IP variation exactly `imem_ip` and save it under `quartus/ip/imem_ip/`.
6. Select Verilog HDL generation.
7. Set data width to `32` bits.
8. Set number of words/depth to `1024`.
9. Use a single clock.
10. Do not create a byte-enable port.
11. Select `M10K` if the parameter editor offers an explicit memory-block type. `Auto` is also legal, but verify M10K use in the compilation report.
12. Keep the RAM synchronous and configure the `q` output as **unregistered** / no extra output register. This project wrapper assumes one clock from request to usable data. If you enable an additional q output register, the wrapper must be changed for two-cycle latency.
13. Enable initial memory contents and select `quartus/soc_demo.mif`.
14. Generate the IP and synthesis/simulation files.
15. Confirm the generated top-level module is named `imem_ip` and has ports compatible with:
    - `address[9:0]`
    - `clock`
    - `data[31:0]`
    - `wren`
    - `q[31:0]`

The wrapper ties `wren=0`, so this RAM is used as program memory.

## IP 2: Data SRAM (`dmem_ip`)

1. In IP Catalog, create another `RAM: 1-PORT` variation.
2. Name it exactly `dmem_ip`; save under `quartus/ip/dmem_ip/`.
3. Data width = `32`.
4. Depth = `1024` words.
5. Single clock.
6. Turn **Create byte enable for port A** ON.
7. Byte-enable width = `8 bits per byte`; the generated `byteena` port must therefore be 4 bits wide.
8. Use M10K or Auto; verify after synthesis.
9. Configure `q` as unregistered/no extra output register.
10. Initial contents can be blank/zero.
11. Generate the IP.
12. Confirm ports compatible with:
    - `address[9:0]`
    - `byteena[3:0]`
    - `clock`
    - `data[31:0]`
    - `wren`
    - `q[31:0]`

`byteena[3:0]` connects directly to the already-verified RV32I LSU `wstrb[3:0]` behavior for SB/SH/SW.

## IP 3: Configuration SRAM (`cfg_ip`)

For the first working implementation, use a 1-port RAM initialized from a MIF. This keeps the final FPGA architecture simple. If your supervisor specifically requires run-time testbench writes through a second physical port, convert this IP to `RAM: 2-PORT` later; the CPU side does not need to change.

1. Create `RAM: 1-PORT` again.
2. Name it exactly `cfg_ip`; save under `quartus/ip/cfg_ip/`.
3. Data width = `32`.
4. Depth = `256` words.
5. Single clock.
6. Enable byte enable, 8-bit byte width -> `byteena[3:0]`.
7. Use M10K or Auto.
8. Configure `q` as unregistered/no extra output register.
9. Enable initialization and select `quartus/config_demo.mif`.
10. Generate the IP.
11. Confirm ports compatible with:
    - `address[7:0]`
    - `byteena[3:0]`
    - `clock`
    - `data[31:0]`
    - `wren`
    - `q[31:0]`

`config_demo.mif` contains:

- word 0 = 100 (`PWM period`)
- word 1 = 30 (`PWM duty`)
- word 2 = 0x48 (`UART 'H'`)
- word 3 = 0xA5 (`SPI transmit byte`)

## After generating all three IPs

1. In Quartus Project Navigator / Settings > Files, confirm the generated IP `.qip` / `.ip` files are part of the project. If the wizard did not add them automatically, add them manually.
2. Do not add the old behavioral memories (`instruction_sram.sv`, `data_sram.sv`, `config_sram.sv`) to the final Quartus synthesis project.
3. The final Quartus top remains `riscv_fan_soc_fpga_top`.
4. Run `Processing > Start > Start Analysis & Elaboration` first.
5. Fix any IP port-name mismatch before continuing.
6. Then run `Analysis & Synthesis`.
7. In the Compilation Report, check RAM/Memory usage and confirm embedded M10K blocks are used.

## ModelSim before actual generated IP

A simulation-only stand-in is provided:

`tb/models_ip/intel_ram_ip_sim_models.sv`

Run:

```tcl
quit -sim
do sim/tests/run_sram_ip_wrappers.do
```

Expected:

```text
[PASS] tb_sram_ip_wrappers
```

Then test the new multicycle CPU handshake:

```tcl
quit -sim
do sim/tests/run_rv32i_core_multicycle.do
```

Expected:

```text
[PASS] tb_rv32i_core_multicycle
```

Do not compile `tb/models_ip/intel_ram_ip_sim_models.sv` together with the real generated IP simulation HDL because both define modules named `imem_ip`, `dmem_ip`, and `cfg_ip`.
