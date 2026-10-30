"""List byte tables a 32-bit Windows exe indexes with movzx reg, byte [index + table].

Used to locate Wolf4SDL's vgaCeiling[] (per-level ceiling colour) in the SR
and EoD SDL executables, whose values MCS changed from stock Spear.

usage: bytetables.py EXE-SOURCE [--len 30] [--grep HEXBYTE]
"""
import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata


def sections(d):
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    optsize = struct.unpack_from("<H", d, pe + 20)[0]
    base = struct.unpack_from("<I", d, pe + 24 + 28)[0]
    out = []
    for k in range(nsec):
        s = pe + 24 + optsize + 40 * k
        name = d[s:s + 8].rstrip(b"\0").decode("latin1")
        vsize, vaddr, rsize, raddr = struct.unpack_from("<4I", d, s + 8)
        out.append((name, base + vaddr, max(vsize, rsize), raddr))
    return base, out


def to_offset(secs, va):
    for name, start, size, raw in secs:
        if start <= va < start + size:
            return raw + (va - start), name
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exe")
    ap.add_argument("--len", type=int, default=30)
    ap.add_argument("--grep", help="only tables containing this byte (hex)")
    args = ap.parse_args()
    d = wolfdata.read(args.exe)
    base, secs = sections(d)
    seen = {}
    for i in range(len(d) - 7):
        # 0F B6 /r with mod=10 (disp32) and rm != 100 (no SIB): movzx r32, byte [reg + disp32]
        if d[i] != 0x0F or d[i + 1] != 0xB6:
            continue
        modrm = d[i + 2]
        mod, rm = modrm >> 6, modrm & 7
        if mod == 2 and rm != 4:  # [reg + disp32]
            va = struct.unpack_from("<I", d, i + 3)[0]
        elif rm == 4 and (mod == 2 or (mod == 0 and d[i + 3] & 7 == 5)):  # SIB + disp32
            va = struct.unpack_from("<I", d, i + 4)[0]
        else:
            continue
        off, name = to_offset(secs, va)
        if off is None or name in (".text", "CODE"):
            continue
        seen.setdefault(va, (off, name, []))[2].append(i)
    want = int(args.grep, 16) if args.grep else None
    for va, (off, name, refs) in sorted(seen.items()):
        data = d[off:off + args.len]
        if want is not None and want not in data:
            continue
        print(f"{va:#010x} {name:6} refs={len(refs):2}  " + " ".join("%02X" % b for b in data))


if __name__ == "__main__":
    main()
