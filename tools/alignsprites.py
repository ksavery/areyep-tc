"""Fuzzy-align a mod's VSWAP sprites against a reference VSWAP.

AReyeP's sprites were re-saved with drop shadows, so nothing matches byte for
byte. For each mod sprite this finds the reference sprite whose opaque pixels
it reproduces best (shadow pixels on either side are ignored), then prints
runs of consecutive matches with a constant offset.

usage: alignsprites.py MOD-VSWAP REF-VSWAP REF-GRAPHICMAP [--min 0.8]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import graphicmap
import wolfdata


def flat(px):
    return [v for row in px for v in row]


def score(mod, ref, shadow):
    """Fraction of the reference's non-shadow opaque pixels the mod sprite matches."""
    want = hit = 0
    for m, r in zip(mod, ref):
        if r is None or r in shadow:
            continue
        want += 1
        hit += m == r
    return hit / want if want else 0.0


def shadow_indices(vs):
    """Palette indices used in the bottom rows of most sprites (drop shadows)."""
    counts = {}
    total = 0
    for i in range(vs.sound_start - vs.sprite_start):
        px = vs.sprite(i)
        if not px:
            continue
        total += 1
        for v in set(v for row in px[56:] for v in row if v is not None):
            counts[v] = counts.get(v, 0) + 1
    return {v for v, c in counts.items() if c > total * 0.4}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mod")
    ap.add_argument("ref")
    ap.add_argument("refmap")
    ap.add_argument("--min", type=float, default=0.8)
    args = ap.parse_args()

    mod = wolfdata.VSwap(wolfdata.read(args.mod))
    ref = wolfdata.VSwap(wolfdata.read(args.ref))
    names = graphicmap.read_list(args.refmap)
    shadow = shadow_indices(mod)
    print(f"shadow palette indices: {sorted(shadow)}")

    refs = []
    for j in range(ref.sound_start - ref.sprite_start):
        px = ref.sprite(j)
        refs.append(flat(px) if px else None)

    best = []
    for i in range(mod.sound_start - mod.sprite_start):
        px = mod.sprite(i)
        if not px:
            best.append((None, 0.0))
            continue
        m = flat(px)
        cand = (None, 0.0)
        # Search near the same position first; sprite tables mostly keep order
        for j in sorted(range(len(refs)), key=lambda j: abs(j - i)):
            if refs[j] is None:
                continue
            s = score(m, refs[j], shadow)
            if s > cand[1]:
                cand = (j, s)
                if s > 0.98:
                    break
        best.append(cand if cand[1] >= args.min else (None, cand[1]))

    runs = []
    for i, (j, s) in enumerate(best):
        d = None if j is None else j - i
        if runs and runs[-1][2] == d and runs[-1][1] == i - 1:
            runs[-1][1] = i
            runs[-1][3] = min(runs[-1][3], s)
        else:
            runs.append([i, i, d, s])
    for a, b, d, s in runs:
        if d is None:
            print(f"{a:3}-{b:3}  no match")
        else:
            n = lambda k: names[k][0][0] if k < len(names) and names[k] else "?"
            print(f"{a:3}-{b:3}  = ref {a + d}-{b + d}  ({n(a + d)} .. {n(b + d)})  min score {s:.2f}")


if __name__ == "__main__":
    main()
