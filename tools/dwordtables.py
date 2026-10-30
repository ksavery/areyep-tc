"""List dword tables a 32-bit Windows exe reads with mov reg, [index*4 + table].

Companion to bytetables.py for finding Wolf4SDL's vgaCeiling[] (an unsigned[]
holding doubled colour bytes, e.g. 0x00001d1d) in SDL builds.

usage: dwordtables.py EXE-SOURCE [--count 30] [--doubled]
"""
import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata
from bytetables import sections, to_offset


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exe")
    ap.add_argument("--count", type=int, default=30)
    ap.add_argument("--doubled", action="store_true", help="only tables whose first entries are 0x0000XXXX doubled bytes")
    args = ap.parse_args()
    d = wolfdata.read(args.exe)
    base, secs = sections(d)
    seen = {}
    for i in range(len(d) - 7):
        if d[i] != 0x8B:
            continue
        modrm, sib = d[i + 1], d[i + 2]
        # mod=00 rm=100 (SIB), SIB scale=4 (10), base=101 (disp32, no base)
        if modrm >> 6 != 0 or modrm & 7 != 4 or sib >> 6 != 2 or sib & 7 != 5:
            continue
        va = struct.unpack_from("<I", d, i + 3)[0]
        off, name = to_offset(secs, va)
        if off is None or name in (".text", ".bss"):
            continue
        seen.setdefault(va, [off, name, 0])[2] += 1
    for va, (off, name, refs) in sorted(seen.items()):
        vals = struct.unpack_from("<%dI" % args.count, d, off) if off + 4 * args.count <= len(d) else ()
        if args.doubled and not all(v < 0x10000 and v & 0xFF == v >> 8 for v in vals[:4]):
            continue
        print(f"{va:#010x} {name:6} refs={refs:2}  " + " ".join("%X" % v for v in vals))


if __name__ == "__main__":
    main()
