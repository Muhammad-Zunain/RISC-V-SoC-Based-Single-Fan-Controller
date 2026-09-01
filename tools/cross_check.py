#!/usr/bin/env python3
"""Offline structural/firmware cross-check for the multicycle RISC-V fan SoC.

Final architecture:
- Multicycle RV32I core
- Quartus M10K IP wrappers for IMEM/DMEM/CFG
- Simulation Intel RAM IP models
- PWM / UART / SPI MMIO peripherals

Legacy behavioral SRAM files may remain in the repository for reference,
but they are NOT part of the final synthesis/simulation architecture.
"""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]

errors = []


# ==============================================================
# FINAL ACTIVE SOURCE LISTS
# ==============================================================

ACTIVE_RTL = [

    "rtl/common/soc_pkg.sv",

    "rtl/core/rv32i_alu.sv",
    "rtl/core/rv32i_regfile.sv",
    "rtl/core/rv32i_imm_gen.sv",
    "rtl/core/rv32i_decoder.sv",
    "rtl/core/rv32i_branch_unit.sv",
    "rtl/core/rv32i_lsu.sv",
    "rtl/core/rv32i_core.sv",

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
    "rtl/soc/riscv_fan_soc_fpga_top.sv",
]


SIM_SUPPORT = [

    "tb/models/spi_slave_model.sv",
    "tb/models/uart_terminal_model.sv",
    "tb/models/virtual_fan_model.sv",

    "tb/models_ip/intel_ram_ip_sim_models.sv",
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


LEGACY_RTL = [

    "rtl/memory/instruction_sram.sv",
    "rtl/memory/data_sram.sv",
    "rtl/memory/config_sram.sv",
]


# ==============================================================
# HELPERS
# ==============================================================

def clean_sv(text):

    text = re.sub(
        r"/\*.*?\*/",
        "",
        text,
        flags=re.S
    )

    text = re.sub(
        r"//.*",
        "",
        text
    )

    text = re.sub(
        r'"(?:\\.|[^"\\])*"',
        '""',
        text
    )

    return text


def listed_paths(path):

    if not path.exists():
        return []

    result = []

    for line in path.read_text().splitlines():

        line = line.strip()

        if (
            line
            and not line.startswith("#")
        ):
            result.append(line)

    return result


def require_file(path_string):

    if not (ROOT / path_string).exists():

        errors.append(
            "Missing required file: "
            + path_string
        )


# ==============================================================
# 1. REQUIRED FILES
# ==============================================================

for path in (
    ACTIVE_RTL
    + SIM_SUPPORT
    + ACTIVE_TBS
):

    require_file(path)


for path in [

    "quartus/ip/imem_ip.qip",
    "quartus/ip/imem_ip.v",

    "quartus/ip/dmem_ip.qip",
    "quartus/ip/dmem_ip.v",

    "quartus/ip/cfg_ip.qip",
    "quartus/ip/cfg_ip.v",

]:

    require_file(path)


# ==============================================================
# 2. MODEL-SIM FILELIST
# ==============================================================

filelist = ROOT / "sim/filelist.f"

if not filelist.exists():

    errors.append(
        "sim/filelist.f missing"
    )

else:

    filelist_entries = listed_paths(
        filelist
    )

    for path in ACTIVE_RTL + SIM_SUPPORT:

        if path not in filelist_entries:

            errors.append(
                "sim/filelist.f missing: "
                + path
            )

    # Legacy SRAM must NOT be compiled.
    for path in LEGACY_RTL:

        if path in filelist_entries:

            errors.append(
                "sim/filelist.f still contains old SRAM: "
                + path
            )


# ==============================================================
# 3. RTL FILELIST
# ==============================================================

filelist_rtl = ROOT / "sim/filelist_rtl.f"

if not filelist_rtl.exists():

    errors.append(
        "sim/filelist_rtl.f missing"
    )

else:

    rtl_entries = listed_paths(
        filelist_rtl
    )

    expected = (
        ACTIVE_RTL
        +
        [
            "tb/models_ip/"
            "intel_ram_ip_sim_models.sv"
        ]
    )

    for path in expected:

        if path not in rtl_entries:

            errors.append(
                "sim/filelist_rtl.f missing: "
                + path
            )

    for path in LEGACY_RTL:

        if path in rtl_entries:

            errors.append(
                "sim/filelist_rtl.f still contains old SRAM: "
                + path
            )


# ==============================================================
# 4. MODULE INVENTORY
# ==============================================================

scan_files = []

for path in (
    ACTIVE_RTL
    + SIM_SUPPORT
    + ACTIVE_TBS
):

    file_path = ROOT / path

    if file_path.exists():

        scan_files.append(
            file_path
        )


modules = {}


for file_path in scan_files:

    text = clean_sv(
        file_path.read_text()
    )

    relative_path = (
        file_path.relative_to(ROOT)
    )

    # ----------------------------------------------------------
    # Basic begin/end balance
    # ----------------------------------------------------------

    checks = [

        (
            r"\bmodule\b",
            r"\bendmodule\b",
            "module/endmodule"
        ),

        (
            r"\bbegin\b",
            r"\bend\b",
            "begin/end"
        ),

        (
            r"\bcase(?:x|z)?\b",
            r"\bendcase\b",
            "case/endcase"
        ),

        (
            r"\bfunction\b",
            r"\bendfunction\b",
            "function/endfunction"
        ),

        (
            r"\btask\b",
            r"\bendtask\b",
            "task/endtask"
        ),

    ]

    for left, right, label in checks:

        count_left = len(
            re.findall(
                left,
                text
            )
        )

        count_right = len(
            re.findall(
                right,
                text
            )
        )

        if count_left != count_right:

            errors.append(
                f"{relative_path}: "
                f"unbalanced {label} "
                f"{count_left}/{count_right}"
            )

    # ----------------------------------------------------------
    # Bracket balance
    # ----------------------------------------------------------

    for left, right, label in [

        ("(", ")", "parentheses"),
        ("[", "]", "brackets"),
        ("{", "}", "braces"),

    ]:

        if (
            text.count(left)
            !=
            text.count(right)
        ):

            errors.append(
                f"{relative_path}: "
                f"unbalanced {label}"
            )

    # ----------------------------------------------------------
    # Find module declarations
    # ----------------------------------------------------------

    for match in re.finditer(
        r"\bmodule\s+([A-Za-z_]\w*)",
        text
    ):

        module_name = (
            match.group(1)
        )

        if module_name in modules:

            errors.append(
                "Duplicate active module: "
                + module_name
            )

        modules[module_name] = (
            relative_path
        )


# ==============================================================
# 5. REQUIRED FINAL RTL MODULES
# ==============================================================

required_modules = {

    "rv32i_alu",
    "rv32i_regfile",
    "rv32i_imm_gen",
    "rv32i_decoder",
    "rv32i_branch_unit",
    "rv32i_lsu",
    "rv32i_core",

    "imem_ip_wrapper",
    "dmem_ip_wrapper",
    "config_ip_wrapper",

    "pwm_peripheral",

    "uart_tx",
    "uart_rx",
    "uart_peripheral",

    "spi_master",
    "spi_peripheral",

    "mmio_decoder",
    "riscv_fan_soc",
    "riscv_fan_soc_fpga_top",
}


missing_modules = (
    required_modules
    -
    set(modules)
)


if missing_modules:

    errors.append(
        "Missing final RTL modules: "
        +
        ", ".join(
            sorted(missing_modules)
        )
    )


# ==============================================================
# 6. SIMULATION SRAM IP MODULES
# ==============================================================

for module_name in [

    "imem_ip",
    "dmem_ip",
    "cfg_ip",

]:

    if module_name not in modules:

        errors.append(
            "Simulation RAM model missing: "
            + module_name
        )


# ==============================================================
# 7. DIRECT TESTBENCH COVERAGE
# ==============================================================

test_map = {

    "rv32i_alu":
        "tb_alu",

    "rv32i_regfile":
        "tb_regfile",

    "rv32i_imm_gen":
        "tb_imm_gen",

    "rv32i_decoder":
        "tb_decoder",

    "rv32i_branch_unit":
        "tb_branch_unit",

    "rv32i_lsu":
        "tb_lsu",

    "rv32i_core":
        "tb_rv32i_core",

    "imem_ip_wrapper":
        "tb_sram_ip_wrappers",

    "dmem_ip_wrapper":
        "tb_sram_ip_wrappers",

    "config_ip_wrapper":
        "tb_sram_ip_wrappers",

    "pwm_peripheral":
        "tb_pwm",

    "uart_tx":
        "tb_uart_tx",

    "uart_rx":
        "tb_uart_rx",

    "uart_peripheral":
        "tb_uart_peripheral",

    "spi_master":
        "tb_spi_master",

    "spi_peripheral":
        "tb_spi_peripheral",

    "mmio_decoder":
        "tb_mmio_decoder",

    "riscv_fan_soc":
        "tb_soc",
}


for rtl_module, tb_module in (
    test_map.items()
):

    if (
        rtl_module in modules
        and
        tb_module not in modules
    ):

        errors.append(
            rtl_module
            +
            " missing testbench "
            +
            tb_module
        )


if "tb_rv32i_core_multicycle" not in modules:

    errors.append(
        "Missing explicit multicycle CPU testbench"
    )


# ==============================================================
# 8. SYNTHESIZABILITY CHECK
# ==============================================================

for path in ACTIVE_RTL:

    file_path = ROOT / path

    if not file_path.exists():
        continue

    text = clean_sv(
        file_path.read_text()
    )

    # Timing delays must not appear in RTL.
    if re.search(
        r"(^|[^\w])#\s*\d",
        text
    ):

        errors.append(
            path
            +
            ": timing delay found in RTL"
        )

    for bad in [

        "$display",
        "$fatal",
        "$finish",
        "$stop",
        "force ",
        "release ",

    ]:

        if bad in text:

            errors.append(
                path
                +
                ": simulation-only construct "
                +
                bad
            )


# ==============================================================
# 9. QUARTUS PROJECT CHECK
# ==============================================================

qsf = (
    ROOT
    /
    "quartus/riscv_fan_soc.qsf"
)


if not qsf.exists():

    errors.append(
        "Quartus QSF missing"
    )

else:

    qsf_text = (
        qsf.read_text()
    )

    # ----------------------------------------------------------
    # Active RTL must be in QSF
    # ----------------------------------------------------------

    for path in ACTIVE_RTL:

        expected = (
            "../"
            +
            path.replace("\\", "/")
        )

        if expected not in qsf_text:

            errors.append(
                "Quartus QSF missing: "
                + expected
            )

    # ----------------------------------------------------------
    # Old behavioral SRAM must NOT be in QSF
    # ----------------------------------------------------------

    for path in LEGACY_RTL:

        expected = (
            "../"
            +
            path
        )

        if expected in qsf_text:

            errors.append(
                "Quartus QSF contains legacy SRAM: "
                + expected
            )

    # ----------------------------------------------------------
    # Generated IP QIPs
    # ----------------------------------------------------------

    for qip in [

        "ip/imem_ip.qip",
        "ip/dmem_ip.qip",
        "ip/cfg_ip.qip",

    ]:

        if qip not in qsf_text:

            errors.append(
                "Quartus QSF missing QIP: "
                + qip
            )

    # ----------------------------------------------------------
    # Top level
    # ----------------------------------------------------------

    if (
        "TOP_LEVEL_ENTITY "
        "riscv_fan_soc_fpga_top"
        not in qsf_text
    ):

        errors.append(
            "Wrong Quartus top-level entity"
        )


# ==============================================================
# 10. GENERATED SRAM IP SETTINGS
# ==============================================================

IP_EXPECTATIONS = {

    "imem_ip": {

        'numwords_a = 1024':
            "depth 1024",

        'width_a = 32':
            "width 32",

        'widthad_a = 10':
            "address width 10",

        'outdata_reg_a = "UNREGISTERED"':
            "q unregistered",

        'ram_block_type = "M10K"':
            "M10K",

        'init_file = "soc_demo.mif"':
            "soc_demo.mif",
    },

    "dmem_ip": {

        'numwords_a = 1024':
            "depth 1024",

        'width_a = 32':
            "width 32",

        'widthad_a = 10':
            "address width 10",

        'outdata_reg_a = "UNREGISTERED"':
            "q unregistered",

        'ram_block_type = "M10K"':
            "M10K",

        'byte_size = 8':
            "8-bit byte enable",
    },

    "cfg_ip": {

        'numwords_a = 256':
            "depth 256",

        'width_a = 32':
            "width 32",

        'widthad_a = 8':
            "address width 8",

        'outdata_reg_a = "UNREGISTERED"':
            "q unregistered",

        'ram_block_type = "M10K"':
            "M10K",

        'byte_size = 8':
            "8-bit byte enable",

        'init_file = "config_demo.mif"':
            "config_demo.mif",
    },
}


for ip_name, checks in (
    IP_EXPECTATIONS.items()
):

    qip_path = (
        ROOT
        /
        f"quartus/ip/{ip_name}.qip"
    )

    verilog_path = (
        ROOT
        /
        f"quartus/ip/{ip_name}.v"
    )

    if not qip_path.exists():
        continue

    if not verilog_path.exists():
        continue

    qip_text = (
        qip_path.read_text()
    )

    if (
        f"{ip_name}.v"
        not in qip_text
    ):

        errors.append(
            f"{ip_name}.qip does not "
            f"reference {ip_name}.v"
        )

    verilog_text = (
        verilog_path.read_text()
    )

    for token, description in (
        checks.items()
    ):

        if token not in verilog_text:

            errors.append(
                f"{ip_name} incorrect setting: "
                f"{description}"
            )


# ==============================================================
# 11. COMPILE_ALL.DO
# ==============================================================

compile_script = (
    ROOT
    /
    "sim/compile_all.do"
)


if not compile_script.exists():

    errors.append(
        "sim/compile_all.do missing"
    )

else:

    compile_text = (
        compile_script.read_text()
    )

    if (
        "-f sim/filelist.f"
        not in compile_text
    ):

        errors.append(
            "compile_all.do does not use "
            "sim/filelist.f"
        )

    for tb_path in ACTIVE_TBS:

        if tb_path not in compile_text:

            errors.append(
                "compile_all.do missing TB: "
                + tb_path
            )

    # Old SRAM TBs must not compile.
    for old_tb in [

        "tb/memory/tb_instruction_sram.sv",
        "tb/memory/tb_data_sram.sv",
        "tb/memory/tb_config_sram.sv",

    ]:

        if old_tb in compile_text:

            errors.append(
                "compile_all.do still compiles "
                "legacy testbench: "
                +
                old_tb
            )


# ==============================================================
# 12. RUN_ALL.DO
# ==============================================================

run_script = (
    ROOT
    /
    "sim/run_all.do"
)


if not run_script.exists():

    errors.append(
        "sim/run_all.do missing"
    )

else:

    run_text = (
        run_script.read_text()
    )

    for tb_path in ACTIVE_TBS:

        tb_name = (
            Path(tb_path).stem
        )

        expected = (
            "work."
            +
            tb_name
        )

        if expected not in run_text:

            errors.append(
                "run_all.do does not run "
                +
                tb_name
            )


# ==============================================================
# 13. MULTICYCLE CORE STRUCTURE
# ==============================================================

core_path = (
    ROOT
    /
    "rtl/core/rv32i_core.sv"
)


if core_path.exists():

    core_text = (
        core_path.read_text()
    )

    # ----------------------------------------------------------
    # Required FSM states
    # ----------------------------------------------------------

    for state_name in [

        "ST_FETCH_REQ",
        "ST_FETCH_WAIT",
        "ST_DECODE",
        "ST_EXECUTE",
        "ST_ALU_WB",
        "ST_MEM_REQ",
        "ST_MEM_WAIT",
        "ST_LOAD_WB",
        "ST_TRAP",

    ]:

        if state_name not in core_text:

            errors.append(
                "rv32i_core missing state "
                +
                state_name
            )

    # ----------------------------------------------------------
    # Req/ready interface
    # ----------------------------------------------------------

    for signal_name in [

        "imem_req_o",
        "imem_ready_i",
        "dmem_req_o",
        "dmem_ready_i",

    ]:

        if signal_name not in core_text:

            errors.append(
                "rv32i_core missing handshake: "
                +
                signal_name
            )

    # ----------------------------------------------------------
    # Trap-protected writeback
    # ----------------------------------------------------------

    if (
        "if (!halted_o && !trap_request)"
        not in core_text
    ):

        errors.append(
            "rv32i_core missing "
            "trap-protected writeback"
        )


# ==============================================================
# 14. SOC TRANSACTION HANDSHAKE
# ==============================================================

soc_path = (
    ROOT
    /
    "rtl/soc/riscv_fan_soc.sv"
)


if soc_path.exists():

    soc_text = (
        soc_path.read_text()
    )

    if (
        "if (!target_valid_q && cpu_req)"
        not in soc_text
    ):

        errors.append(
            "SoC missing transaction capture logic"
        )

    if (
        "target_valid_q && cpu_ready"
        not in soc_text
    ):

        errors.append(
            "SoC missing transaction completion logic"
        )

    if (
        "if (decode_fault)"
        not in soc_text
    ):

        errors.append(
            "SoC missing MMIO fault priority"
        )


# ==============================================================
# 15. FIRMWARE REFERENCE CHECK
# ==============================================================

hex_path = (
    ROOT
    /
    "firmware/soc_demo.hex"
)

cfg_path = (
    ROOT
    /
    "firmware/config_demo.hex"
)


if (
    not hex_path.exists()
    or
    not cfg_path.exists()
):

    errors.append(
        "Firmware/config HEX files missing"
    )

else:

    words = [

        int(value, 16)

        for value
        in hex_path.read_text().split()
    ]

    cfg_words = [

        int(value, 16)

        for value
        in cfg_path.read_text().split()
    ]

    # ----------------------------------------------------------
    # Configuration values
    # ----------------------------------------------------------

    if cfg_words[:4] != [

        100,
        30,
        0x48,
        0xA5,

    ]:

        errors.append(
            "Configuration data incorrect: "
            +
            str(cfg_words[:4])
        )

    # ----------------------------------------------------------
    # Demo program currently expected to have 28 words
    # ----------------------------------------------------------

    if len(words) != 28:

        errors.append(
            "soc_demo.hex expected "
            "28 words, got "
            +
            str(len(words))
        )

    # ----------------------------------------------------------
    # Quartus HEX copies must match firmware
    # ----------------------------------------------------------

    quartus_soc_hex = (
        ROOT
        /
        "quartus/soc_demo.hex"
    )

    quartus_cfg_hex = (
        ROOT
        /
        "quartus/config_demo.hex"
    )

    if (
        not quartus_soc_hex.exists()
        or
        quartus_soc_hex.read_text()
        !=
        hex_path.read_text()
    ):

        errors.append(
            "quartus/soc_demo.hex "
            "missing or stale"
        )

    if (
        not quartus_cfg_hex.exists()
        or
        quartus_cfg_hex.read_text()
        !=
        cfg_path.read_text()
    ):

        errors.append(
            "quartus/config_demo.hex "
            "missing or stale"
        )

    # ==========================================================
    # Tiny firmware reference executor
    # ==========================================================

    regs = [0] * 32

    pc = 0

    cfg = {

        0x20000000 + (4 * index):
            value

        for index, value
        in enumerate(cfg_words)
    }

    dmem = {}

    pwm_registers = {}

    uart_tx_values = []

    spi_tx_value = None

    steps = 0

    reached_final_loop = False

    firmware_error = False


    def sext(value, bits):

        sign = (
            1
            <<
            (bits - 1)
        )

        if value & sign:

            return (
                value
                -
                (1 << bits)
            )

        return value


    def memory_load(address):

        # Configuration SRAM
        if address in cfg:

            return cfg[address]

        # Data SRAM
        if (
            0x10000000
            <=
            address
            <
            0x10001000
        ):

            return dmem.get(
                address,
                0
            )

        # SPI STATUS: done
        if address == 0x40002008:

            return 0x2

        # SPI RXDATA
        if address == 0x4000200C:

            return 0x3C

        # UART STATUS: RX valid
        if address == 0x40001008:

            return 0x2

        # UART RXDATA
        if address == 0x40001004:

            return 0x5A

        return 0


    def memory_store(address, value):

        value &= 0xFFFFFFFF

        # Data SRAM
        if (
            0x10000000
            <=
            address
            <
            0x10001000
        ):

            dmem[address] = value

        # PWM
        elif (
            0x40000000
            <=
            address
            <=
            0x40000008
        ):

            pwm_registers[address] = value

        # UART TXDATA
        elif address == 0x40001000:

            uart_tx_values.append(
                value & 0xFF
            )

        # SPI TXDATA
        elif address == 0x40002000:

            return (
                value & 0xFF
            )

        return None


    while (
        steps < 200
        and
        not firmware_error
    ):

        # ------------------------------------------------------
        # PC validity
        # ------------------------------------------------------

        if (
            pc % 4
            or
            pc // 4 >= len(words)
        ):

            errors.append(
                f"Firmware PC out of range "
                f"0x{pc:08X}"
            )

            firmware_error = True

            break

        instruction = (
            words[pc // 4]
        )

        opcode = (
            instruction
            &
            0x7F
        )

        rd = (
            instruction >> 7
        ) & 31

        funct3 = (
            instruction >> 12
        ) & 7

        rs1 = (
            instruction >> 15
        ) & 31

        rs2 = (
            instruction >> 20
        ) & 31

        next_pc = (
            pc + 4
        ) & 0xFFFFFFFF

        write_value = None

        # ------------------------------------------------------
        # LUI
        # ------------------------------------------------------

        if opcode == 0x37:

            write_value = (
                instruction
                &
                0xFFFFF000
            )

        # ------------------------------------------------------
        # LW
        # ------------------------------------------------------

        elif (
            opcode == 0x03
            and
            funct3 == 2
        ):

            immediate = sext(
                (instruction >> 20)
                &
                0xFFF,
                12
            )

            address = (
                regs[rs1]
                +
                immediate
            ) & 0xFFFFFFFF

            write_value = (
                memory_load(address)
            )

        # ------------------------------------------------------
        # SW
        # ------------------------------------------------------

        elif (
            opcode == 0x23
            and
            funct3 == 2
        ):

            immediate = sext(

                (
                    (instruction >> 25)
                    << 5
                )
                |
                (
                    (instruction >> 7)
                    &
                    31
                ),

                12
            )

            address = (
                regs[rs1]
                +
                immediate
            ) & 0xFFFFFFFF

            result = memory_store(
                address,
                regs[rs2]
            )

            if result is not None:

                spi_tx_value = result

        # ------------------------------------------------------
        # ADDI / ANDI
        # ------------------------------------------------------

        elif opcode == 0x13:

            immediate = sext(
                (instruction >> 20)
                &
                0xFFF,
                12
            )

            if funct3 == 0:

                write_value = (
                    regs[rs1]
                    +
                    immediate
                ) & 0xFFFFFFFF

            elif funct3 == 7:

                write_value = (
                    regs[rs1]
                    &
                    (
                        immediate
                        &
                        0xFFFFFFFF
                    )
                )

            else:

                errors.append(
                    "Unexpected firmware "
                    f"OP-IMM funct3={funct3}"
                )

                firmware_error = True

                break

        # ------------------------------------------------------
        # BEQ
        # ------------------------------------------------------

        elif (
            opcode == 0x63
            and
            funct3 == 0
        ):

            immediate = (

                (
                    (
                        instruction >> 31
                    )
                    &
                    1
                )
                << 12

            ) | (

                (
                    (
                        instruction >> 7
                    )
                    &
                    1
                )
                << 11

            ) | (

                (
                    (
                        instruction >> 25
                    )
                    &
                    0x3F
                )
                << 5

            ) | (

                (
                    (
                        instruction >> 8
                    )
                    &
                    0xF
                )
                << 1

            )

            immediate = sext(
                immediate,
                13
            )

            if regs[rs1] == regs[rs2]:

                next_pc = (
                    pc
                    +
                    immediate
                ) & 0xFFFFFFFF

        # ------------------------------------------------------
        # JAL
        # ------------------------------------------------------

        elif opcode == 0x6F:

            immediate = (

                (
                    (
                        instruction >> 31
                    )
                    &
                    1
                )
                << 20

            ) | (

                (
                    (
                        instruction >> 12
                    )
                    &
                    0xFF
                )
                << 12

            ) | (

                (
                    (
                        instruction >> 20
                    )
                    &
                    1
                )
                << 11

            ) | (

                (
                    (
                        instruction >> 21
                    )
                    &
                    0x3FF
                )
                << 1

            )

            immediate = sext(
                immediate,
                21
            )

            write_value = (
                pc + 4
            ) & 0xFFFFFFFF

            next_pc = (
                pc
                +
                immediate
            ) & 0xFFFFFFFF

            # Final infinite loop:
            #
            #     JAL x0,0
            #
            if (
                rd == 0
                and
                immediate == 0
            ):

                reached_final_loop = True

                break

        else:

            errors.append(
                f"Unexpected firmware opcode "
                f"0x{opcode:02X} "
                f"at PC=0x{pc:X}"
            )

            firmware_error = True

            break

        # ------------------------------------------------------
        # Register writeback
        # ------------------------------------------------------

        if (
            write_value is not None
            and
            rd != 0
        ):

            regs[rd] = (
                write_value
                &
                0xFFFFFFFF
            )

        regs[0] = 0

        pc = next_pc

        steps += 1

    # ==========================================================
    # Firmware final expected behavior
    # ==========================================================

    if not reached_final_loop:

        errors.append(
            "Firmware did not reach "
            "final JAL x0,0"
        )

    if (

        pwm_registers.get(
            0x40000000
        ) != 1

        or

        pwm_registers.get(
            0x40000004
        ) != 100

        or

        pwm_registers.get(
            0x40000008
        ) != 30

    ):

        errors.append(
            "Firmware PWM mismatch: "
            +
            str(pwm_registers)
        )

    if uart_tx_values != [0x48]:

        errors.append(
            "Firmware UART TX mismatch: "
            +
            str(uart_tx_values)
        )

    if spi_tx_value != 0xA5:

        errors.append(
            "Firmware SPI TX mismatch: "
            +
            str(spi_tx_value)
        )

    if (

        dmem.get(
            0x10000000
        ) != 0x3C

        or

        dmem.get(
            0x10000004
        ) != 0x5A

    ):

        errors.append(
            "Firmware DMEM result mismatch: "
            +
            str(dmem)
        )


# ==============================================================
# FINAL RESULT
# ==============================================================

if errors:

    print("")
    print("========================================")
    print("CROSS-CHECK FAILED")
    print("========================================")

    for error in errors:

        print(
            " -",
            error
        )

    print("")

    sys.exit(1)


print("")
print("========================================")
print("CROSS-CHECK PASS")
print("========================================")

print(
    f" - {len(ACTIVE_RTL)} "
    "active synthesizable RTL files checked"
)

print(
    f" - {len(ACTIVE_TBS)} "
    "active testbenches checked"
)

print(
    f" - {len(modules)} "
    "active modules/models/testbenches found"
)

print(
    f" - {len(test_map)} "
    "RTL-to-testbench checks passed"
)

print(
    " - Multicycle RV32I FSM checked"
)

print(
    " - IMEM/DMEM req-ready handshake checked"
)

print(
    " - Quartus M10K IP settings checked"
)

print(
    " - Quartus final source list checked"
)

print(
    " - ModelSim compile/regression lists checked"
)

print(
    " - Demo firmware reference execution passed"
)

print(
    " - Expected demo:"
)

print(
    "     PWM = period 100, duty 30"
)

print(
    "     Virtual fan = 30%"
)

print(
    "     UART TX = 0x48 ('H')"
)

print(
    "     UART RX = 0x5A"
)

print(
    "     SPI TX = 0xA5"
)

print(
    "     SPI RX = 0x3C"
)

print("")