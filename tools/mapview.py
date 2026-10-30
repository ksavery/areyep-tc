"""Render a top-down view of one map: walls with their VSWAP texture, doors
tinted, object codes printed on their tiles, the player start marked.

usage: mapview.py MAPHEAD GAMEMAPS VSWAP MAPNUM OUT.png [--around-start N] [--cell 24]
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata
from sheet import load_palette, render_wall, ROOT
from tcpath import TC


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maphead")
    ap.add_argument("gamemaps")
    ap.add_argument("vswap")
    ap.add_argument("mapnum", type=int)
    ap.add_argument("out")
    ap.add_argument("--around-start", type=int, help="crop to this many tiles around the player start")
    ap.add_argument("--cell", type=int, default=24)
    ap.add_argument("--palette", default=str(TC / "Data/Palettes/Spear.pal"))
    args = ap.parse_args()

    pal = load_palette(args.palette)
    vs = wolfdata.VSwap(wolfdata.read(args.vswap))
    m = [x for x in wolfdata.read_maps(wolfdata.read(args.maphead), wolfdata.read(args.gamemaps)) if x.index == args.mapnum][0]
    w, h, c = m.width, m.height, args.cell

    x0, y0, x1, y1 = 0, 0, w, h
    start = next(((i % w, i // w) for i, v in enumerate(m.planes[1]) if 19 <= v <= 22), None)
    if args.around_start and start:
        r = args.around_start
        x0, y0 = max(0, start[0] - r), max(0, start[1] - r)
        x1, y1 = min(w, start[0] + r + 1), min(h, start[1] + r + 1)

    tex = {}
    img = Image.new("RGB", ((x1 - x0) * c, (y1 - y0) * c), (90, 90, 90))
    draw = ImageDraw.Draw(img)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = m.planes[0][y * w + x]
            o = m.planes[1][y * w + x]
            px, py = (x - x0) * c, (y - y0) * c
            if 1 <= t <= 0x59:
                page = (t - 1) * 2
                if page not in tex:
                    tex[page] = render_wall(vs, page, pal).convert("RGB").resize((c, c))
                img.paste(tex[page], (px, py))
                draw.text((px + 1, py + 1), "%X" % t, fill=(255, 255, 0))
            elif 0x5A <= t <= 0x69:
                draw.rectangle([px, py, px + c - 1, py + c - 1], fill=(120, 60, 160))
                draw.text((px + 1, py + 1), "%X" % t, fill=(255, 255, 255))
            if o:
                col = (0, 255, 0) if 19 <= o <= 22 else (255, 255, 255)
                draw.text((px + 1, py + c // 2), str(o), fill=col)
    img.save(args.out)
    print(f"{m.name}: start {start}, view {x0},{y0}-{x1},{y1}")


if __name__ == "__main__":
    main()
