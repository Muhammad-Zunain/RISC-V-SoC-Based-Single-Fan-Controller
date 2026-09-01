#!/usr/bin/env python3
"""Convert simple one-32-bit-word-per-line hex files into Quartus MIF files."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def convert(src, dst, depth, default_word):
    words = []
    for raw in Path(src).read_text().splitlines():
        line = raw.strip()
        if line and not line.startswith('#'):
            words.append(int(line, 16))
    if len(words) > depth:
        raise ValueError(f"{src} has {len(words)} words but depth is {depth}")

    with Path(dst).open('w') as f:
        f.write('WIDTH=32;\n')
        f.write(f'DEPTH={depth};\n\n')
        f.write('ADDRESS_RADIX=HEX;\n')
        f.write('DATA_RADIX=HEX;\n\n')
        f.write('CONTENT BEGIN\n')
        for address, word in enumerate(words):
            f.write(f'    {address:X} : {word:08X};\n')
        if len(words) < depth:
            f.write(f'    [{len(words):X}..{depth-1:X}] : {default_word:08X};\n')
        f.write('END;\n')


if __name__ == '__main__':
    convert(ROOT/'firmware'/'soc_demo.hex', ROOT/'quartus'/'soc_demo.mif', 1024, 0x00000013)
    convert(ROOT/'firmware'/'config_demo.hex', ROOT/'quartus'/'config_demo.mif', 256, 0x00000000)
    print('Generated quartus/soc_demo.mif and quartus/config_demo.mif')
