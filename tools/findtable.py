"""Look for Wolf3D's per-level ceiling colour table in a game executable.

The DOS code stores vgaCeiling[] as words with the colour in both bytes
(0x6f6f, 0x4f4f, ...); Wolf4SDL keeps the doubled values as 32-bit ints. Prints long runs of
doubled-byte words, and where stock Spear's table appears in either form.

usage: findtable.py EXE-SOURCE [--min 18] [--max 40]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata

SPEAR = [0x6F, 0x4F, 0x1D, 0xDE, 0xDF, 0x2E, 0x7F, 0x9E, 0xAE, 0x7F, 0x1D,
         0xDE, 0xDF, 0xDE, 0xDF, 0xDE, 0xE1, 0xDC, 0x2E, 0x1D, 0xDC]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exe")
    ap.add_argument("--min", type=int, default=18)
    ap.add_argument("--max", type=int, default=40)
    ap.add_argument("--distinct", type=int, default=5)
    args = ap.parse_args()
    d = wolfdata.read(args.exe)
    print(f"{len(d)} bytes, LZEXE packed: {b'LZ91' in d[:64]}")
    print("stock Spear table as bytes at", d.find(bytes(SPEAR[:6])),
          "as words at", d.find(b"".join(bytes([b, b]) for b in SPEAR[:6])))
    # Wolf4SDL builds declare it unsigned (32-bit): colour colour 00 00
    i = 0
    while i < len(d) - 3:
        j, vals = i, []
        while j + 3 < len(d) and d[j] == d[j + 1] and d[j + 2] == 0 and d[j + 3] == 0 and d[j]:
            vals.append(d[j])
            j += 4
        if args.min <= len(vals) <= args.max and len(set(vals)) >= args.distinct:
            print(f"dword run at {i:#x}: {len(vals)} entries: " + " ".join("%02X" % v for v in vals))
        i = j if j > i else i + 1

    i = 0
    while i < len(d) - 1:
        j, vals = i, []
        while j + 1 < len(d) and d[j] == d[j + 1]:
            vals.append(d[j])
            j += 2
        if args.min <= len(vals) <= args.max and len(set(vals)) >= args.distinct:
            print(f"word run at {i:#x}: {len(vals)} entries: " + " ".join("%02X" % v for v in vals))
        i = j if j > i else i + 1


if __name__ == "__main__":
    main()
