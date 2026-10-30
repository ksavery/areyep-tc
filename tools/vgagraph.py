"""Read Wolf3D-engine VGAGRAPH files (VGAHEAD offsets + VGADICT Huffman tree).

Chunk 0 is the picture size table, chunks 1-2 are fonts (STARTFONT), pictures
start at chunk 3 (STARTPICS) and are stored as four VGA planes.

usage: vgagraph.py STAGED-DIR EXT OUTDIR [--palette FILE]
       dumps every picture as OUTDIR/<chunk>.png and prints the size table
"""
import argparse
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from tcpath import TC


def huff_expand(src, length, tree):
    """Wolf3D's Huffman: tree nodes are (bit0, bit1) words; < 256 is a leaf, else node - 256."""
    out = bytearray()
    node = 254  # head node
    pos, bit = 0, 0
    while len(out) < length:
        b = src[pos]
        val = tree[node][(b >> bit) & 1]
        bit += 1
        if bit == 8:
            bit, pos = 0, pos + 1
        if val < 256:
            out.append(val)
            node = 254
        else:
            node = val - 256
    return bytes(out)


class VGAGraph:
    def __init__(self, head, graph, dictionary):
        self.graph = graph
        self.offsets = [int.from_bytes(head[i:i + 3], "little") for i in range(0, len(head) - 2, 3)]
        words = struct.unpack("<510H", dictionary[:1020])
        self.tree = [(words[2 * i], words[2 * i + 1]) for i in range(255)]
        # The picture table's stored length is unreliable in AReyeP's files (FloEdit
        # wrote 423 for a ~620-byte table), so expand it fully and stop at the first
        # empty entry.
        raw = graph[self.offsets[0] + 4:self.offsets[1]] + b"\0" * 64
        sizes = huff_expand(raw, (len(self.offsets) - 1) * 4, self.tree)
        self.picsizes = []
        for i in range(0, len(sizes) - 3, 4):
            w, h = struct.unpack_from("<2H", sizes, i)
            if not w or not h:
                break
            self.picsizes.append((w, h))

    def chunk(self, n):
        start = self.offsets[n]
        if start == 0xFFFFFF:
            return b""
        end = next((o for o in self.offsets[n + 1:] if o != 0xFFFFFF), len(self.graph))
        data = self.graph[start:end]
        length = struct.unpack_from("<I", data, 0)[0]
        return huff_expand(data[4:], length, self.tree)

    def picture(self, n, palette, first=3):
        """Picture chunk n (absolute chunk number) as an RGB image."""
        w, h = self.picsizes[n - first]
        data = self.chunk(n)
        im = Image.new("RGB", (w, h))
        quarter = (w // 4) * h
        px = im.load()
        for y in range(h):
            for x in range(w):
                px[x, y] = palette[data[(y * (w // 4) + x // 4) + (x % 4) * quarter]]
        return im


def load_palette(path):
    vals = list(map(int, Path(path).read_text().split()[3:]))
    return [tuple(vals[i:i + 3]) for i in range(0, 768, 3)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("staged")
    ap.add_argument("ext")
    ap.add_argument("outdir")
    ap.add_argument("--palette", default=str(TC / "Data/Palettes/Spear.pal"))
    args = ap.parse_args()
    d = Path(args.staged)
    vg = VGAGraph((d / f"VGAHEAD.{args.ext}").read_bytes(), (d / f"VGAGRAPH.{args.ext}").read_bytes(),
                  (d / f"VGADICT.{args.ext}").read_bytes())
    pal = load_palette(args.palette)
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    for i, (w, h) in enumerate(vg.picsizes):
        n = i + 3
        try:
            vg.picture(n, pal).save(out / f"{n:04d}.png")
            print(n, w, h)
        except Exception as e:  # sizes table can run past the real pictures
            print(n, w, h, "skip:", e)


if __name__ == "__main__":
    main()
