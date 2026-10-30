"""Histogram wall (plane 0) and object (plane 1) codes across a mod's maps,
flagging codes the stock TC Default/SD1 tables don't define."""
import collections
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata
from tcpath import TC

ROOT = Path(__file__).resolve().parent.parent


def known_objects():
    known = set()
    for f in ("Default.txt", "SD1.txt"):
        txt = (TC / "Data/TileCodes" / f).read_text()
        known |= {int(m) for m in re.findall(r"^\s*(\d+)\s*=", txt, re.M)}
    return known


def main(label, head, maps, first=0, last=None):
    ms = wolfdata.read_maps(wolfdata.read(head), wolfdata.read(maps))[first:last]
    p0, p1 = collections.Counter(), collections.Counter()
    where = collections.defaultdict(set)
    for m in ms:
        for v in m.planes[0]:
            p0[v] += 1
        for v in m.planes[1]:
            if v:
                p1[v] += 1
                where[v].add(m.index)
    known = known_objects()
    print(f"== {label}: {len(ms)} maps")
    walls = sorted(v for v in p0 if v < 0x6A)
    print("  plane0 <0x6A:", " ".join(f"{v:#x}" for v in walls))
    print("  plane0 >=0x6A (floor/area/other):", " ".join(f"{v:#x}" for v in sorted(v for v in p0 if v >= 0x6A)))
    unk = [v for v in sorted(p1) if v not in known and not 98 <= v <= 98]
    print("  plane1 unknown:", ", ".join(f"{v}(x{p1[v]} m{sorted(where[v])[:4]})" for v in unk))
    print("  plane1 known used:", " ".join(str(v) for v in sorted(p1) if v in known))


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], a[1], a[2], int(a[3]) if len(a) > 3 else 0, int(a[4]) if len(a) > 4 else None)
