"""Stage AReyeP game data from the original release archives into a game folder.

The repo never contains AReyeP/MCS data; this script pulls it from your own
copies of the downloads (found by archive name under the --source roots) and
writes it under the extensions the TC expects:

  VSWAP.SR    shared art/sounds for both Spear Resurrection mapsets
  *.SR1       Spear Resurrection, original 2001 maps   (Spearres.zip)
  *.SR2       Spear Resurrection, 2011 SDL new mapset  (SRSDL2.ZIP)
  *.EOD       End of Destiny, editor's version v1.12   (EOD_112.ZIP)
  *.WFD        Wolfendoom, 2001                          (Wolfdoom.zip)

usage: stage.py OUTDIR [--source DIR ...]
"""
import argparse
import hashlib
import struct
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata

# (archive name, member, staged name, expected md5 prefix or None)
FILES = [
    ("Spearres.zip", "VSWAP.RIP", "VSWAP.SR", "02ec5d44"),
    ("Spearres.zip", "GAMEMAPS.RIP", "GAMEMAPS.SR1", None),
    ("Spearres.zip", "MAPHEAD.RIP", "MAPHEAD.SR1", None),
    ("Spearres.zip", "AUDIOHED.RIP", "AUDIOHED.SR1", None),
    ("Spearres.zip", "AUDIOT.RIP", "AUDIOT.SR1", None),
    ("Spearres.zip", "VGAHEAD.RIP", "VGAHEAD.SR1", None),
    ("Spearres.zip", "VGADICT.RIP", "VGADICT.SR1", None),
    ("Spearres.zip", "VGAGRAPH.RIP", "VGAGRAPH.SR1", None),
    ("SRSDL2.ZIP", "GAMEMAPS.RIP", "GAMEMAPS.SR2", None),
    ("SRSDL2.ZIP", "MAPHEAD.RIP", "MAPHEAD.SR2", None),
    ("SRSDL2.ZIP", "AUDIOHED.RIP", "AUDIOHED.SR2", None),
    ("SRSDL2.ZIP", "AUDIOT.RIP", "AUDIOT.SR2", None),
    ("SRSDL2.ZIP", "VGAHEAD.RIP", "VGAHEAD.SR2", None),
    ("SRSDL2.ZIP", "VGADICT.RIP", "VGADICT.SR2", None),
    ("SRSDL2.ZIP", "VGAGRAPH.RIP", "VGAGRAPH.SR2", None),
    ("EOD_112.ZIP", "VSWAP.WL6", "VSWAP.EOD", "05c152a9"),
    ("EOD_112.ZIP", "GAMEMAPS.WL6", "GAMEMAPS.EOD", None),
    ("EOD_112.ZIP", "MAPHEAD.WL6", "MAPHEAD.EOD", None),
    ("EOD_112.ZIP", "AUDIOHED.WL6", "AUDIOHED.EOD", None),
    ("EOD_112.ZIP", "AUDIOT.WL6", "AUDIOT.EOD", None),
    ("EOD_112.ZIP", "VGAHEAD.WL6", "VGAHEAD.EOD", None),
    ("EOD_112.ZIP", "VGADICT.WL6", "VGADICT.EOD", None),
    ("EOD_112.ZIP", "VGAGRAPH.WL6", "VGAGRAPH.EOD", None),
    ("EOD_112.ZIP", "SPEAR.EXE", "SPEAR.EOD", None),  # for its game palette (tools/assets.py)
    ("Spearres.zip", "HELPART.RIP", "HELPART.SR1", None),  # Read This! (EoD's is a VGAGRAPH chunk)
    # Wolfendoom: a Wolfenstein 3D mod, so stock WL6 layout throughout
    ("Wolfdoom.zip", "VSWAP.WL6", "VSWAP.WFD", "4f54abe0"),
    ("Wolfdoom.zip", "GAMEMAPS.WL6", "GAMEMAPS.WFD", None),
    ("Wolfdoom.zip", "MAPHEAD.WL6", "MAPHEAD.WFD", None),
    ("Wolfdoom.zip", "AUDIOHED.WL6", "AUDIOHED.WFD", None),
    ("Wolfdoom.zip", "AUDIOT.WL6", "AUDIOT.WFD", None),
    ("Wolfdoom.zip", "VGAHEAD.WL6", "VGAHEAD.WFD", None),
    ("Wolfdoom.zip", "VGADICT.WL6", "VGADICT.WFD", None),
    ("Wolfdoom.zip", "VGAGRAPH.WL6", "VGAGRAPH.WFD", None),
    ("Wolfdoom.zip", "Wolfdoom.exe", "WOLFDOOM.WFD", None),  # level names, par times, engine changes
    ("Wolfdoom.zip", "Helpart.wl6", "HELPART.WFD", None),  # Read This!
    ("Wolfdoom.zip", "Endart1.wl6", "ENDART1.WFD", None),  # episode ending texts
    ("Wolfdoom.zip", "Endart2.wl6", "ENDART2.WFD", None),
    ("Wolfdoom.zip", "Endart3.wl6", "ENDART3.WFD", None),
    ("Wolfdoom.zip", "Endart4.wl6", "ENDART4.WFD", None),
    ("Wolfdoom.zip", "Endart5.wl6", "ENDART5.WFD", None),
    ("Wolfdoom.zip", "Endart6.wl6", "ENDART6.WFD", None),
]

# Real levels per mapset; later MAPHEAD slots hold the "Hope You Have Fun"
# placeholder maps that ship in the 60-slot TED5 files.
LEVELS = {"SR1": 23, "SR2": 23, "EOD": 38, "WFD": 60}


def find_archive(name, roots):
    for root in roots:
        for p in Path(root).rglob("*"):
            if p.name.upper() == name.upper() and p.is_file():
                return p
    return None


def trim_maphead(data, keep):
    count = (len(data) - 2) // 4
    offsets = list(struct.unpack_from("<%dI" % count, data, 2))
    offsets[keep:] = [0] * (count - keep)
    return data[:2] + struct.pack("<%dI" % count, *offsets) + data[2 + 4 * count:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("--source", action="append", default=[],
                    help="folder to search for the release archives (repeatable; default: the current folder)")
    args = ap.parse_args()
    roots = args.source or ["."]

    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    archives = {}
    ok = True
    for arcname, member, staged, md5 in FILES:
        if arcname not in archives:
            archives[arcname] = find_archive(arcname, roots)
        arc = archives[arcname]
        if not arc:
            print(f"missing archive {arcname} (looked under {', '.join(roots)})")
            ok = False
            continue
        data = wolfdata.read(f"{arc}::{member}")
        if md5 and not hashlib.md5(data).hexdigest().startswith(md5):
            print(f"warning: {arc.name}:{member} is not the expected release ({md5})")
        stem, ext = staged.split(".")
        if stem == "MAPHEAD":
            data = trim_maphead(data, LEVELS[ext])
        (out / staged).write_bytes(data)
        print(f"{staged:14} <- {arc.name}:{member}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
