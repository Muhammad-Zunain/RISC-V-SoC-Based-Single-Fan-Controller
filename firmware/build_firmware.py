#!/usr/bin/env python3
"""Generate the bundled RV32I end-to-end demo without an external toolchain."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def u(imm20, rd, op):
    return ((imm20 & 0xfffff) << 12) | (rd << 7) | op

def i(imm, rs1, f3, rd, op):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def s(imm, rs2, rs1, f3):
    x = imm & 0xfff
    return ((x >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((x & 0x1f) << 7) | 0x23

def b(imm, rs2, rs1, f3):
    x = imm & 0x1fff
    return (((x >> 12) & 1) << 31) | (((x >> 5) & 0x3f) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((x >> 1) & 0xf) << 8) | (((x >> 11) & 1) << 7) | 0x63

def j(imm, rd):
    x = imm & 0x1fffff
    return (((x >> 20) & 1) << 31) | (((x >> 1) & 0x3ff) << 21) | (((x >> 11) & 1) << 20) | (((x >> 12) & 0xff) << 12) | (rd << 7) | 0x6f

LUI = 0x37
LOAD = 0x03
OPIMM = 0x13

p = []
p += [u(0x20000, 10, LUI)]                   # x10 = CFG base
p += [i(0,10,2,1,LOAD), i(4,10,2,2,LOAD)]   # x1 period, x2 duty
p += [u(0x40000,11,LUI)]                     # x11 = PWM base
p += [i(1,0,0,3,OPIMM), s(0,3,11,2), s(4,1,11,2), s(8,2,11,2)]
p += [u(0x40001,12,LUI)]                     # x12 = UART base
p += [i(8,10,2,4,LOAD), s(0,4,12,2)]        # transmit configured character
p += [u(0x40002,13,LUI)]                     # x13 = SPI base
p += [i(12,10,2,5,LOAD), s(0,5,13,2), i(1,0,0,6,OPIMM), s(4,6,13,2)]
p += [i(8,13,2,7,LOAD), i(2,7,7,7,OPIMM), b(-8,0,7,0)]  # poll SPI done
p += [i(12,13,2,8,LOAD)]                    # x8 = SPI RX
p += [u(0x10000,14,LUI), s(0,8,14,2)]       # save SPI RX to DMEM[0]
p += [i(8,12,2,9,LOAD), i(2,9,7,9,OPIMM), b(-8,0,9,0)]  # poll UART RX valid
p += [i(4,12,2,15,LOAD), s(4,15,14,2)]      # save UART RX to DMEM[1]
p += [j(0,0)]                                # loop forever

soc_text = "\n".join(f"{x:08x}" for x in p) + "\n"
(ROOT / "soc_demo.hex").write_text(soc_text)
# Capstone nominal test configuration: 100-clock PWM period, 30-clock high time,
# UART 'H', and SPI byte A5.
config = [100, 30, 0x48, 0xA5]
cfg_text = "\n".join(f"{x:08x}" for x in config) + "\n"
(ROOT / "config_demo.hex").write_text(cfg_text)
quartus_dir = ROOT.parent / "quartus"
if quartus_dir.exists():
    (quartus_dir / "soc_demo.hex").write_text(soc_text)
    (quartus_dir / "config_demo.hex").write_text(cfg_text)
print(f"wrote soc_demo.hex ({len(p)} words) and config_demo.hex")
