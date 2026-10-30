"""Render a VSWAP's walls or sprites to a labelled contact sheet PNG.

usage: sheet.py VSWAP-SOURCE walls|sprites OUT.png [--start N] [--count N] [--cols N]
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata

ROOT = Path(__file__).resolve().parent.parent
from tcpath import TC


def load_palette(path):
    vals = list(map(int, Path(path).read_text().split()[3:]))
    return [tuple(vals[i:i + 3]) for i in range(0, 768, 3)]


CELL = 64 + 12


def render_wall(vs, i, pal):
    data = vs.wall(i)
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    if len(data) < 4096:
        return im
    for x in range(64):
        for y in range(64):
            im.putpixel((x, y), pal[data[x * 64 + y]] + (255,))
    return im


def render_sprite(vs, i, pal):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = vs.sprite(i)
    if px:
        for y, row in enumerate(px):
            for x, v in enumerate(row):
                if v is not None:
                    im.putpixel((x, y), pal[v] + (255,))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vswap")
    ap.add_argument("kind", choices=("walls", "sprites"))
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--count", type=int)
    ap.add_argument("--cols", type=int, default=16)
    ap.add_argument("--palette", default=str(TC / "Data/Palettes/Spear.pal"))
    args = ap.parse_args()

    pal = load_palette(args.palette)
    vs = wolfdata.VSwap(wolfdata.read(args.vswap))
    total = vs.sprite_start if args.kind == "walls" else vs.sound_start - vs.sprite_start
    count = min(args.count or total, total - args.start)
    rows = (count + args.cols - 1) // args.cols
    sheet = Image.new("RGBA", (args.cols * CELL, rows * CELL), (40, 40, 60, 255))
    draw = ImageDraw.Draw(sheet)
    render = render_wall if args.kind == "walls" else render_sprite
    for n in range(count):
        i = args.start + n
        x, y = (n % args.cols) * CELL, (n // args.cols) * CELL
        sheet.alpha_composite(render(vs, i, pal), (x + 6, y + 10))
        draw.text((x + 2, y), str(i), fill=(255, 255, 0, 255))
    sheet.save(args.out)


if __name__ == "__main__":
    main()
