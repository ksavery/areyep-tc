"""Add the game, map and times to saves from before the menus used them.

usage: tag-saves.py SAVEDIR [--write]
Without --write it only reports. With it, the folder is first copied beside
itself. The engine's autosaves are copied to ordinary saves, since the menus
don't list them. Run with the game closed; run/ needs the staged GAMEMAPS files.
"""
import json
import re
import shutil
import sys
import time
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata

RUN = Path(__file__).parent.parent / "run"
SEPARATOR = "\x1f"
KEEP = 4  # Autosaves for each game, as SaveInfo.KEEPAUTOSAVES
TITLES = {"SR1": "Spear Resurrection", "SR2": "Spear Resurrection (New Maps)", "EOD": "Spear: End of Destiny", "WFD": "Wolfendoom"}
BASES = {"SR1": 2000, "SR2": 3000, "EOD": 4000, "WFD": 5000}


def maps_of(game):
    return list(wolfdata.read_maps(wolfdata.read(str(RUN / f"MAPHEAD.{game}")), wolfdata.read(str(RUN / f"GAMEMAPS.{game}"))))


def map_number(game, index):
    if game == "WFD":
        return BASES[game] + (index // 10 + 1) * 100 + index % 10 + 1
    return BASES[game] + index + 1


def read_save(path):
    with zipfile.ZipFile(path) as z:
        info = json.loads(z.read("info.json"))
        level = z.read("level.map.json").decode("utf8", "replace")
        server = json.loads(z.read("globals.json"))["servercvars"]
    return info, level, server


def find_map(game, level, maps):
    """By its record, or for older saves by where the level's things are."""
    found = re.search(r'"mapnum":(\d+)', level)
    if found:
        for index, m in enumerate(maps):
            if map_number(game, index) == int(found[1]):
                return m, map_number(game, index), "record"

    spots = re.findall(r'"classtype":"(?:NaziFlag|FloorLamp|Plant|PlantinVase|GreenCeilingLight|RedCeilingLight|PlateofFood|FirstAidKit|WolfClip|WolfClipBox)".{0,120}?"pos":\[(-?[\d.]+),(-?[\d.]+)', level)
    best, number, score = None, 0, -1
    for index, m in enumerate(maps):
        hits = 0
        for x, y in spots:
            col, row = int((float(x) + 2048) // 64), int((2048 - float(y)) // 64)
            if 0 <= col < 64 and 0 <= row < 64 and m.planes[1][row * 64 + col]:
                hits += 1
        if hits > score:
            best, number, score = m, map_number(game, index), hits
    return best, number, f"things {score}/{len(spots)}"


def retitle(source, target, title):
    temp = target.with_suffix(".tmp")
    with zipfile.ZipFile(source) as z, zipfile.ZipFile(temp, "w") as out:
        for item in z.infolist():
            data = z.read(item)
            if item.filename == "info.json":
                info = json.loads(data)
                info["Title"] = title
                data = json.dumps(info, ensure_ascii=False).encode("utf8")
            out.writestr(item, data, item.compress_type)
    temp.replace(target)


def main():
    folder = Path(sys.argv[1])
    write = "--write" in sys.argv
    maps = {}
    plans = []

    for path in sorted(folder.glob("*.zds")):
        info, level, server = read_save(path)
        title = info["Title"]
        engine_auto = path.stem.startswith("auto")

        tagged = SEPARATOR in title
        if tagged and title.count("|") >= 4:
            print(f"{path.name}: already tagged")
            continue
        if info.get("Game WAD") != "Wolf3D-TC.ipk3":
            print(f"{path.name}: skipped, made by {info.get('Game WAD')}")
            continue

        game = server.get("g_modgame", "").upper()
        if game not in TITLES:
            print(f"{path.name}: skipped, game {game!r}")
            continue

        maps.setdefault(game, maps_of(game))
        found, number, how = find_map(game, level, maps[game])
        data = json.loads(level)
        tag = f"{TITLES[game]}|{found.name.strip().replace('|', '/')}|{data.get('maptime', 0)}|{data.get('totaltime', 0)}|{number % 100}"
        plans.append((path, title.split(SEPARATOR)[0], tag, game, engine_auto))
        print(f"{path.name}: {title!r} -> {game} {found.name.strip()!r} ({how}), level {data.get('maptime', 0) // 35}s, total {data.get('totaltime', 0) // 35}s")

    # Newest autosaves first, so a game keeps the ones it would have
    autosaves = sorted((p for p in plans if p[4]), key=lambda p: p[1], reverse=True)
    kept = {}
    copies = []
    have = {p[1] for p in plans if not p[4]}
    have |= {read_save(p)[0]["Title"].split(SEPARATOR)[0] for p in folder.glob("save*.zds")}
    for plan in autosaves:
        if plan[1] in have:
            continue
        kept[plan[3]] = kept.get(plan[3], 0) + 1
        if kept[plan[3]] <= KEEP:
            copies.append(plan)

    if write:
        backup = folder.with_name(f"{folder.name}-backup-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copytree(folder, backup)
        print(f"backup: {backup}")

    used = {p.stem for p in folder.glob("save*.zds")}
    number = 0
    for path, title, tag, game, _ in copies:
        while f"save{number:02d}" in used:
            number += 1
        used.add(f"save{number:02d}")
        print(f"{path.name}: copied to save{number:02d}.zds")
        if write:
            retitle(path, folder / f"save{number:02d}.zds", title + SEPARATOR + tag)

    if not write:
        print("(nothing changed: --write to do this)")
        return 0

    for path, title, tag, _, engine_auto in plans:
        if not engine_auto:
            retitle(path, path, title + SEPARATOR + tag)

    return 0


sys.exit(main())
