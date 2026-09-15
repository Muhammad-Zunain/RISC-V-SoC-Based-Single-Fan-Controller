#!/usr/bin/env python3
"""ASIC-oriented offline structural and firmware cross-check.

This checker intentionally validates the active ASIC-neutral RTL architecture.
Quartus/Intel RAM files are treated as legacy artifacts and are not required by
this flow.  The final synthesis path uses ASIC_USE_SRAM_MACROS and the logical
memory macro boundary defined in rtl/memory_macro/asic_sram_macro_stubs.sv.
"""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
notes = []

SIM_RTL = [
    "rtl/common/soc_pkg.sv",
    "rtl/core/rv32i_alu.sv",
    "rtl/core/rv32i_regfile.sv",
    "rtl/core/rv32i_imm_gen.sv",
    "rtl/core/rv32i_decoder.sv",
    "rtl/core/rv32i_branch_unit.sv",
    "rtl/core/rv32i_lsu.sv",
    "rtl/core/rv32i_core.sv",
    "rtl/memory_asic/asic_imem.sv",
    "rtl/memory_asic/asic_dmem.sv",
    "rtl/memory_asic/asic_config_mem.sv",
    "rtl/memory_ip/imem_ip_wrapper.sv",
    "rtl/memory_ip/dmem_ip_wrapper.sv",
    "rtl/memory_ip/config_ip_wrapper.sv",
    "rtl/periph/pwm_peripheral.sv",
    "rtl/periph/uart_tx.sv",
    "rtl/periph/uart_rx.sv",
    "rtl/periph/uart_peripheral.sv",
    "rtl/periph/spi_master.sv",
    "rtl/periph/spi_peripheral.sv",
    "rtl/soc/mmio_decoder.sv",
    "rtl/soc/riscv_fan_soc.sv",
    "rtl/soc/riscv_fan_soc_asic_top.sv",
]

ASIC_RTL = SIM_RTL[:8] + ["rtl/memory_macro/asic_sram_macro_stubs.sv"] + SIM_RTL[8:]

SIM_SUPPORT = [
    "tb/models/spi_slave_model.sv",
    "tb/models/uart_terminal_model.sv",
    "tb/models/virtual_fan_model.sv",
]

ACTIVE_TBS = [
    "tb/core/tb_alu.sv",
    "tb/core/tb_regfile.sv",
    "tb/core/tb_imm_gen.sv",
    "tb/core/tb_branch_unit.sv",
    "tb/core/tb_lsu.sv",
    "tb/core/tb_decoder.sv",
    "tb/core/tb_rv32i_core.sv",
    "tb/core/tb_rv32i_core_multicycle.sv",
    "tb/core/tb_core_faults.sv",
    "tb/core/tb_core_cycle_count.sv",
    "tb/memory/tb_sram_ip_wrappers.sv",
    "tb/periph/tb_pwm.sv",
    "tb/periph/tb_uart_tx.sv",
    "tb/periph/tb_uart_rx.sv",
    "tb/periph/tb_uart_peripheral.sv",
    "tb/periph/tb_spi_master.sv",
    "tb/periph/tb_spi_peripheral.sv",
    "tb/integration/tb_mmio_decoder.sv",
    "tb/integration/tb_cpu_memory.sv",
    "tb/integration/tb_cpu_pwm.sv",
    "tb/integration/tb_cpu_uart.sv",
    "tb/integration/tb_cpu_spi.sv",
    "tb/integration/tb_error_status.sv",
    "tb/integration/tb_soc.sv",
]

LEGACY_RTL = {
    "rtl/memory/instruction_sram.sv",
    "rtl/memory/data_sram.sv",
    "rtl/memory/config_sram.sv",
    "rtl/soc/riscv_fan_soc_fpga_top.sv",
    "tb/models_ip/intel_ram_ip_sim_models.sv",
}


def read(path):
    p = ROOT / path
    if not p.exists():
        errors.append(f"Missing required file: {path}")
        return ""
    return p.read_text(errors="replace")


def listed(path):
    text = read(path)
    return [x.strip() for x in text.splitlines() if x.strip() and not x.lstrip().startswith("#")]


def clean_sv(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    return text


# 1. Files and source lists.
for p in SIM_RTL + SIM_SUPPORT + ACTIVE_TBS + ["rtl/memory_macro/asic_sram_macro_stubs.sv"]:
    read(p)

sim_entries = listed("sim/filelist.f")
rtl_entries = listed("sim/filelist_rtl.f")
asic_entries = listed("asic/filelist_asic.f")

for p in SIM_RTL + SIM_SUPPORT:
    if p not in sim_entries:
        errors.append(f"sim/filelist.f missing active source: {p}")
for p in SIM_RTL:
    if p not in rtl_entries:
        errors.append(f"sim/filelist_rtl.f missing active RTL: {p}")
for p in ASIC_RTL:
    if p not in asic_entries:
        errors.append(f"asic/filelist_asic.f missing ASIC RTL: {p}")
for p in LEGACY_RTL:
    if p in sim_entries or p in rtl_entries or p in asic_entries:
        errors.append(f"Legacy/FPGA source is active in an ASIC-oriented filelist: {p}")

# 2. Basic SystemVerilog structural sanity for active sources/TBs.
modules = {}
for rel in SIM_RTL + SIM_SUPPORT + ACTIVE_TBS + ["rtl/memory_macro/asic_sram_macro_stubs.sv"]:
    text = clean_sv(read(rel))
    for a, b, label in [
        (r"\bmodule\b", r"\bendmodule\b", "module/endmodule"),
        (r"\bbegin\b", r"\bend\b", "begin/end"),
        (r"\bcase(?:x|z)?\b", r"\bendcase\b", "case/endcase"),
        (r"\bfunction\b", r"\bendfunction\b", "function/endfunction"),
        (r"\btask\b", r"\bendtask\b", "task/endtask"),
    ]:
        ca, cb = len(re.findall(a, text)), len(re.findall(b, text))
        if ca != cb:
            errors.append(f"{rel}: unbalanced {label}: {ca}/{cb}")
    for a, b, label in [("(", ")", "parentheses"), ("[", "]", "brackets"), ("{", "}", "braces")]:
        if text.count(a) != text.count(b):
            errors.append(f"{rel}: unbalanced {label}")
    for m in re.finditer(r"\bmodule\s+([A-Za-z_]\w*)", text):
        name = m.group(1)
        if name in modules and rel != "rtl/memory_macro/asic_sram_macro_stubs.sv":
            errors.append(f"Duplicate active module {name}: {modules[name]} and {rel}")
        modules[name] = rel

required_modules = {
    "rv32i_alu", "rv32i_regfile", "rv32i_imm_gen", "rv32i_decoder",
    "rv32i_branch_unit", "rv32i_lsu", "rv32i_core", "asic_imem",
    "asic_dmem", "asic_config_mem", "imem_ip_wrapper", "dmem_ip_wrapper",
    "config_ip_wrapper", "pwm_peripheral", "uart_tx", "uart_rx",
    "uart_peripheral", "spi_master", "spi_peripheral", "mmio_decoder",
    "riscv_fan_soc", "riscv_fan_soc_asic_top", "asic_imem_macro",
    "asic_dmem_macro", "asic_config_macro",
}
missing = sorted(required_modules - set(modules))
if missing:
    errors.append("Missing required modules: " + ", ".join(missing))

# 3. No accidental standard-cell-memory experiment remains active.
for rel in ["sim/compile_all.do", "asic/genus/genus_script.tcl"] + SIM_RTL + ["rtl/memory_macro/asic_sram_macro_stubs.sv"]:
    if "ASIC_STANDARD_CELL_MEM" in read(rel):
        errors.append(f"Obsolete ASIC_STANDARD_CELL_MEM reference remains in {rel}")

# 4. Logical memory contract: all defaults 256x32, 8-bit word address.
soc = read("rtl/soc/riscv_fan_soc.sv")
asic_top = read("rtl/soc/riscv_fan_soc_asic_top.sv")
decoder = read("rtl/soc/mmio_decoder.sv")
for token, owner in [
    ("parameter integer IMEM_WORDS = 256", "riscv_fan_soc"),
    ("parameter integer DMEM_WORDS = 256", "riscv_fan_soc"),
    ("parameter integer CFG_WORDS  = 256", "riscv_fan_soc"),
    (".IMEM_WORDS(256)", "riscv_fan_soc_asic_top"),
    (".DMEM_WORDS(256)", "riscv_fan_soc_asic_top"),
    (".CFG_WORDS (256)", "riscv_fan_soc_asic_top"),
    ("parameter integer DMEM_WORDS = 256", "mmio_decoder"),
    ("parameter integer CFG_WORDS  = 256", "mmio_decoder"),
]:
    hay = soc if owner == "riscv_fan_soc" else asic_top if owner == "riscv_fan_soc_asic_top" else decoder
    if token not in hay:
        errors.append(f"{owner}: expected logical memory setting not found: {token}")

for rel in [
    "rtl/memory_asic/asic_imem.sv", "rtl/memory_asic/asic_dmem.sv",
    "rtl/memory_asic/asic_config_mem.sv", "rtl/memory_ip/imem_ip_wrapper.sv",
    "rtl/memory_ip/dmem_ip_wrapper.sv", "rtl/memory_ip/config_ip_wrapper.sv",
]:
    if "parameter integer WORDS = 256" not in read(rel) and "parameter integer WORDS  = 256" not in read(rel):
        errors.append(f"{rel}: default WORDS is not 256")

stubs = read("rtl/memory_macro/asic_sram_macro_stubs.sv")
if len(re.findall(r"input\s+logic\s+\[7:0\]\s+addr_i", stubs)) != 3:
    errors.append("Macro stubs must expose three 8-bit word-address ports")
for rel in ["rtl/memory_asic/asic_dmem.sv", "rtl/memory_asic/asic_config_mem.sv"]:
    text = read(rel)
    for lane in range(4):
        if f"wmask_i[{lane}]" not in text:
            errors.append(f"{rel}: missing byte write-mask lane {lane}")

# 5. Wrapper range and latency contract.
for rel in ["rtl/memory_ip/imem_ip_wrapper.sv", "rtl/memory_ip/dmem_ip_wrapper.sv", "rtl/memory_ip/config_ip_wrapper.sv"]:
    text = read(rel)
    if "pending_q <= req_i" not in text:
        errors.append(f"{rel}: one-cycle request/ready pending register not found")
if "addr_i[1:0] != 2'b00" not in read("rtl/memory_ip/imem_ip_wrapper.sv"):
    errors.append("IMEM wrapper must reject non-32-bit-aligned fetch addresses")
if "addr_i >= MEM_BYTES" not in read("rtl/memory_ip/imem_ip_wrapper.sv"):
    errors.append("IMEM wrapper range check missing")
for rel in ["rtl/memory_ip/dmem_ip_wrapper.sv", "rtl/memory_ip/config_ip_wrapper.sv"]:
    text = read(rel)
    if "addr_i >= END_ADDR" not in text or "addr_i < BASE_ADDR" not in text:
        errors.append(f"{rel}: range check missing")

# 6. RV32I architecture checks.
core = read("rtl/core/rv32i_core.sv")
dec = read("rtl/core/rv32i_decoder.sv")
regf = read("rtl/core/rv32i_regfile.sv")
lsu = read("rtl/core/rv32i_lsu.sv")
for state in ["ST_FETCH_REQ", "ST_FETCH_WAIT", "ST_DECODE", "ST_EXECUTE", "ST_ALU_WB", "ST_MEM_REQ", "ST_MEM_WAIT", "ST_LOAD_WB", "ST_TRAP"]:
    if state not in core:
        errors.append(f"rv32i_core missing FSM state {state}")
for sig in ["imem_req_o", "imem_ready_i", "dmem_req_o", "dmem_ready_i"]:
    if sig not in core:
        errors.append(f"rv32i_core missing handshake signal {sig}")
if "if (!halted_o && !trap_request)" not in core:
    errors.append("rv32i_core missing trap-protected architectural writeback")
if "regs[rd_addr_i] <= rd_data_i" not in regf or "rd_addr_i != 5'd0" not in regf:
    errors.append("Register file x0 write protection not found")
if "rs1_addr_i == 5'd0" not in regf or "rs2_addr_i == 5'd0" not in regf:
    errors.append("Register file x0 read-as-zero behavior not found")
for opcode in ["7'b0110111", "7'b0010111", "7'b1101111", "7'b1100111", "7'b1100011", "7'b0000011", "7'b0100011", "7'b0010011", "7'b0110011", "7'b0001111", "7'b1110011"]:
    if opcode not in dec:
        errors.append(f"Decoder missing RV32I opcode {opcode}")
for f3 in ["3'b000", "3'b001", "3'b010", "3'b100", "3'b101"]:
    if f3 not in lsu:
        errors.append(f"LSU appears incomplete for funct3 {f3}")

# 7. SoC transaction capture and priority.
if "if (!target_valid_q && cpu_req)" not in soc:
    errors.append("SoC missing outstanding-target transaction capture")
if "else if (target_valid_q && cpu_ready)" not in soc:
    errors.append("SoC missing outstanding-target completion")
if "if (decode_fault)" not in soc:
    errors.append("SoC missing unmapped-MMIO fault priority")

# 8. Peripheral structural checks.
uart_rx = read("rtl/periph/uart_rx.sv")
if "rx_meta_q <= rx_i" not in uart_rx or "rx_sync_q <= rx_meta_q" not in uart_rx:
    errors.append("UART RX two-flop input synchronizer not found")
spi = read("rtl/periph/spi_master.sv")
if "if (!sclk_o)" not in spi or "rx_shift_q <= {rx_shift_q[6:0], miso_i}" not in spi:
    errors.append("SPI Mode-0 rising-edge sample behavior not found")
if not re.search(r"mosi_o\s*<=\s*tx_data_i\[7\]", spi):
    errors.append("SPI MSB-first preload not found")

# 9. ASIC top reset and observable outputs.
if "@(posedge clk_i or negedge reset_n_i)" not in asic_top:
    errors.append("ASIC top missing asynchronous reset assertion")
if "rst_sync_q <= {rst_sync_q[0], 1'b0}" not in asic_top:
    errors.append("ASIC top missing synchronous reset deassertion shift")
for conn in [".pwm_o                  (pwm_o)", ".uart_tx_o              (uart_tx_o)", ".spi_sclk_o             (spi_sclk_o)", ".spi_mosi_o             (spi_mosi_o)", ".spi_cs_n_o             (spi_cs_n_o)", ".debug_halted_o         (status_halted_o)", ".debug_trap_o           (status_trap_o)"]:
    if conn not in asic_top:
        errors.append(f"ASIC top output connectivity missing: {conn.strip()}")

# 10. Genus ASIC memory mode.
genus = read("asic/genus/genus_script.tcl")
if "read_hdl -sv -define ASIC_USE_SRAM_MACROS $RTL_FILES" not in genus:
    errors.append("Genus must synthesize with ASIC_USE_SRAM_MACROS")
if "riscv_fan_soc_asic_top" not in genus:
    errors.append("Genus top is not riscv_fan_soc_asic_top")

# 11. Compile/run scripts.
compile_do = read("sim/compile_all.do")
if "+define+ASIC_USE_SRAM_MACROS" in compile_do:
    errors.append("Normal ModelSim regression must not enable ASIC macro black boxes")
if "-f sim/filelist.f" not in compile_do:
    errors.append("compile_all.do does not use sim/filelist.f")
for tb in ACTIVE_TBS:
    if tb not in compile_do:
        errors.append(f"compile_all.do missing TB: {tb}")
run_do = read("sim/run_all.do")
for tb in ACTIVE_TBS:
    name = Path(tb).stem
    if f"work.{name}" not in run_do:
        errors.append(f"run_all.do does not execute {name}")

# 12. Firmware/config consistency and tiny reference execution.
hex_path = ROOT / "firmware/soc_demo.hex"
cfg_path = ROOT / "firmware/config_demo.hex"
if not hex_path.exists() or not cfg_path.exists():
    errors.append("Firmware/config HEX files missing")
else:
    words = [int(x, 16) for x in hex_path.read_text().split()]
    cfg_words = [int(x, 16) for x in cfg_path.read_text().split()]
    if len(words) != 28:
        errors.append(f"soc_demo.hex expected 28 words, got {len(words)}")
    if cfg_words[:4] != [100, 30, 0x48, 0xA5]:
        errors.append(f"config_demo.hex first four words are wrong: {cfg_words[:4]}")
    if len(words) > 256:
        errors.append("Firmware no longer fits 256-word IMEM")
    if len(cfg_words) > 256:
        errors.append("Configuration image no longer fits 256-word CFG memory")

    regs = [0] * 32
    pc = 0
    cfg = {0x20000000 + 4*i: v for i, v in enumerate(cfg_words)}
    dmem = {}
    pwm = {}
    uart_tx = []
    spi_tx = None
    reached_loop = False

    def sext(v, bits):
        return v - (1 << bits) if v & (1 << (bits - 1)) else v

    def load(addr):
        if addr in cfg: return cfg[addr]
        if 0x10000000 <= addr < 0x10000400: return dmem.get(addr, 0)
        if addr == 0x40002008: return 0x2
        if addr == 0x4000200C: return 0x3C
        if addr == 0x40001008: return 0x2
        if addr == 0x40001004: return 0x5A
        return 0

    def store(addr, value):
        nonlocal_dummy = None
        value &= 0xFFFFFFFF
        if 0x10000000 <= addr < 0x10000400: dmem[addr] = value
        elif 0x40000000 <= addr <= 0x40000008: pwm[addr] = value
        elif addr == 0x40001000: uart_tx.append(value & 0xFF)
        elif addr == 0x40002000: return value & 0xFF
        return nonlocal_dummy

    for _ in range(200):
        if pc & 3 or pc // 4 >= len(words):
            errors.append(f"Firmware PC out of range/alignment: 0x{pc:08X}")
            break
        insn = words[pc // 4]
        opcode = insn & 0x7F
        rd = (insn >> 7) & 31
        f3 = (insn >> 12) & 7
        rs1 = (insn >> 15) & 31
        rs2 = (insn >> 20) & 31
        npc = (pc + 4) & 0xFFFFFFFF
        wr = None
        if opcode == 0x37:  # LUI
            wr = insn & 0xFFFFF000
        elif opcode == 0x03 and f3 == 2:  # LW
            imm = sext((insn >> 20) & 0xFFF, 12)
            wr = load((regs[rs1] + imm) & 0xFFFFFFFF)
        elif opcode == 0x23 and f3 == 2:  # SW
            imm = sext(((insn >> 25) << 5) | ((insn >> 7) & 31), 12)
            ret = store((regs[rs1] + imm) & 0xFFFFFFFF, regs[rs2])
            if ret is not None: spi_tx = ret
        elif opcode == 0x13 and f3 in (0, 7):
            imm = sext((insn >> 20) & 0xFFF, 12)
            wr = ((regs[rs1] + imm) if f3 == 0 else (regs[rs1] & (imm & 0xFFFFFFFF))) & 0xFFFFFFFF
        elif opcode == 0x63 and f3 == 0:  # BEQ
            imm = (((insn >> 31) & 1) << 12) | (((insn >> 7) & 1) << 11) | (((insn >> 25) & 0x3F) << 5) | (((insn >> 8) & 0xF) << 1)
            imm = sext(imm, 13)
            if regs[rs1] == regs[rs2]: npc = (pc + imm) & 0xFFFFFFFF
        elif opcode == 0x6F:  # JAL
            imm = (((insn >> 31) & 1) << 20) | (((insn >> 12) & 0xFF) << 12) | (((insn >> 20) & 1) << 11) | (((insn >> 21) & 0x3FF) << 1)
            imm = sext(imm, 21)
            wr = (pc + 4) & 0xFFFFFFFF
            npc = (pc + imm) & 0xFFFFFFFF
            if rd == 0 and imm == 0:
                reached_loop = True
                break
        else:
            errors.append(f"Unexpected demo firmware instruction 0x{insn:08X} at PC 0x{pc:08X}")
            break
        if wr is not None and rd != 0: regs[rd] = wr & 0xFFFFFFFF
        regs[0] = 0
        pc = npc

    if not reached_loop: errors.append("Demo firmware did not reach final JAL x0,0 loop")
    if [pwm.get(0x40000000), pwm.get(0x40000004), pwm.get(0x40000008)] != [1, 100, 30]:
        errors.append(f"Firmware PWM programming mismatch: {pwm}")
    if uart_tx != [0x48]: errors.append(f"Firmware UART TX mismatch: {uart_tx}")
    if spi_tx != 0xA5: errors.append(f"Firmware SPI TX mismatch: {spi_tx}")
    if dmem.get(0x10000000) != 0x3C or dmem.get(0x10000004) != 0x5A:
        errors.append(f"Firmware DMEM result mismatch: {dmem}")

# 13. Documentation consistency for active architecture.
map_doc = read("docs/MEMORY_MAP.md")
contract = read("docs/ASIC_MEMORY_MACRO_CONTRACT.md")
for token in ["256 instruction words", "256 data words", "256 configuration words", "0x0000_03FF", "0x1000_03FF", "0x2000_03FF"]:
    if token not in map_doc:
        errors.append(f"MEMORY_MAP.md missing expected active-architecture text: {token}")
for token in ["256 x 32", "8 bits", "one-cycle synchronous read", "four byte write enables", "256 x 16"]:
    if token not in contract:
        errors.append(f"ASIC_MEMORY_MACRO_CONTRACT.md missing: {token}")

if errors:
    print("\n========================================")
    print("ASIC RTL CROSS-CHECK FAILED")
    print("========================================")
    for e in errors: print(" -", e)
    print()
    sys.exit(1)

print("\n========================================")
print("ASIC RTL CROSS-CHECK PASS")
print("========================================")
print(f" - {len(SIM_RTL)} active RTL files checked")
print(f" - {len(ACTIVE_TBS)} active testbenches checked")
print(" - Simulation and ASIC filelists are separated correctly")
print(" - Logical IMEM/DMEM/CFG contract = 256 x 32")
print(" - Macro word address = 8 bits")
print(" - DMEM/CFG preserve four byte-write lanes")
print(" - Multicycle CPU FSM/handshakes checked")
print(" - Trap-protected writeback checked")
print(" - UART RX two-flop synchronizer checked")
print(" - SPI Mode-0/MSB-first structure checked")
print(" - ASIC top reset synchronizer/output connectivity checked")
print(" - Genus macro synthesis mode checked")
print(" - ModelSim compile/run lists checked, including cycle-count TB")
print(" - Firmware fits 256-word IMEM and reference execution passes")
print(" - Expected demo: PWM 100/30, UART H/0x5A, SPI 0xA5/0x3C")
print("\nNOTE: This is an offline structural/reference check, not a replacement for ModelSim, Genus, or LEC.\n")
