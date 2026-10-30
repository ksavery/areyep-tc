# AReyeP TC

Spear Resurrection (original + 2011 new mapset), Spear: End of Destiny and
Wolfendoom, playable in UZDoom as a mod for AFADoomer's [Wolf3D TC 3.0](https://github.com/AFADoomer/Wolf3D-TC-3.0).

**Setup:** [Windows](#setup-on-windows) · [Linux](#setup-on-linux)

## How it fits together

Three pieces make up a working install. This repo is only the second one:

| Piece | Where it comes from | Built into |
|---|---|---|
| **The Wolf3D TC** (the base game) | AFADoomer's repo, cloned next to this one | `run/Wolf3D-TC.ipk3`, loaded as the IWAD |
| **The AReyeP mod** (this repo) | this repo | `run/AReyeP.pk3`, loaded on top of the TC |
| **The game data** | your own copies of AReyeP's downloads | the files you copy into `run/`, plus `run/AReyeP-data.pk3` converted from them |

The mod changes nothing in the TC. It plugs in through the TC's
game-extension hooks (`GameExtension`, answered by `AReyePExtension` here),
the same way any mod loads on top of a base game. No AReyeP/MCS game data is
included: as with the TC, where you copy in your own Wolfenstein 3D or Spear
of Destiny files, you supply the games' files yourself
(https://www.areyep.com/).

When it's set up, the folders look like this:

```
some-folder/
├── Wolf3D-TC-3.0/          ← the TC (AFADoomer's repo)
└── areyep-tc/              ← this repo
    ├── run/                ← the game folder (not in git; created during setup)
    │   ├── VSWAP.SR  GAMEMAPS.SR1  …  GAMEMAPS.WFD  …   ← your game files
    │   ├── AReyeP-data.pk3     ← converted from them (step 3)
    │   ├── Wolf3D-TC.ipk3      ← built from ../Wolf3D-TC-3.0 (step 4)
    │   └── AReyeP.pk3          ← built from this repo (step 4)
    ├── Scripts/ Data/ ZScript.zs …   ← the mod's source
    └── tools/ docs/
```

### Where the build looks for the TC

`tools/tcpath.py` decides, in this order:

1. the `WOLF3D_TC` environment variable, if set: on Windows
   `$env:WOLF3D_TC = "D:\src\Wolf3D-TC-3.0"` before `py tools\build.py`; on
   Linux `WOLF3D_TC=~/src/Wolf3D-TC-3.0 python3 tools/build.py`;
2. otherwise `../Wolf3D-TC-3.0`, a folder of that name next to this repo.

## Setup on Windows

### What you need

| Tool | Used for | Where to get it |
|---|---|---|
| [UZDoom](https://github.com/UZDoom/UZDoom) 5.x | the engine (the TC needs ZScript 5.0) | the release zip; put `uzdoom.exe` on `PATH`, or see step 4 |
| Git | cloning the TC and this repo | [Git for Windows](https://git-scm.com/download/win) |
| Python 3 (tested with 3.14) | the stage, convert and build scripts | the [python.org](https://www.python.org/downloads/) installer; run it as `py` |
| Pillow | converting the games' pictures | `py -m pip install pillow` |

Optional, for the AdLib sound effects (without them they're skipped with a warning):

| Tool | Where to get it |
|---|---|
| MinGW-w64 `g++` | [MSYS2](https://www.msys2.org/), then `pacman -S mingw-w64-ucrt-x86_64-gcc`; add its `ucrt64\bin` folder to `PATH` |
| Kyle Albert's [eod4sdl](https://github.com/kalbert312/eod4sdl) source | cloned in step 1 (its `fmopl.cpp` renders the sounds) |

### Steps

In PowerShell (in `cmd`, set variables with `set NAME=value` instead of
`$env:NAME = "value"`):

**1. Get the TC and the mod side by side**

    git clone https://github.com/AFADoomer/Wolf3D-TC-3.0.git
    git clone https://github.com/ksavery/areyep-tc.git
    git clone https://github.com/kalbert312/eod4sdl.git
    cd areyep-tc

**2. Add your game files**: copy them into a new `run\` folder, renamed as
in [Your game files](#your-game-files). Or let the stage script copy them
from the downloads:

    py tools\stage.py run --source C:\path\to\the\zips

**3. Convert the music and pictures**

    $env:WOLF4SDL = "..\eod4sdl"
    py tools\assets.py run

**4. Build and play**

    py tools\build.py
    tools\play.bat

`play.bat` runs `uzdoom` from `PATH`. If it isn't there, set `UZDOOM` to its
full path first (`$env:UZDOOM = "C:\Games\UZDoom\uzdoom.exe"`) or edit the
line near the top of `play.bat`. Once built, you can also start the game by
double-clicking `tools\play.bat`.

### Notes

- **Renaming in Explorer:** Explorer hides file extensions by default, so
  renaming `VSWAP.RIP` to `VSWAP.SR` can silently give `VSWAP.SR.RIP`. Turn
  on *View → Show → File name extensions* first.
- **Settings** are kept in the game folder, as `run\areyep.ini`.
- Rerun `py tools\build.py` after pulling changes to either repo.

## Setup on Linux

### What you need

| Tool | Used for | Where to get it |
|---|---|---|
| [UZDoom](https://github.com/UZDoom/UZDoom) 5.x | the engine (the TC needs ZScript 5.0) | your distro's package (Arch: AUR `uzdoom-bin`); `uzdoom` on `PATH` |
| git, bash | cloning; `tools/play.sh` | your distro |
| Python 3 (tested with 3.14) | the stage, convert and build scripts | your distro |
| Pillow | converting the games' pictures | your distro's `python-pillow`, or `pip install pillow` |

Optional, for the AdLib sound effects (without them they're skipped with a warning):

| Tool | Where to get it |
|---|---|
| `g++` (or set `CXX` to another C++ compiler) | your distro's `gcc` |
| Kyle Albert's [eod4sdl](https://github.com/kalbert312/eod4sdl) source | cloned in step 1 (its `fmopl.cpp` renders the sounds) |

### Steps

**1. Get the TC and the mod side by side**

    git clone https://github.com/AFADoomer/Wolf3D-TC-3.0.git
    git clone https://github.com/ksavery/areyep-tc.git
    git clone https://github.com/kalbert312/eod4sdl.git
    cd areyep-tc

**2. Add your game files**: copy them into a new `run/` folder, renamed as
in [Your game files](#your-game-files). Or let the stage script copy them
from the downloads:

    python3 tools/stage.py run --source /path/to/the/zips

**3. Convert the music and pictures**

    WOLF4SDL=../eod4sdl python3 tools/assets.py run

**4. Build and play**

    python3 tools/build.py
    tools/play.sh

### Notes

- **Settings** are kept in their own file, `~/.config/uzdoom/areyep.ini`.
- `tools/args.sh` holds the full engine command line `play.sh` uses (and
  `tools/play.bat` the same list for Windows).
- Rerun `python3 tools/build.py` after pulling changes to either repo.

## Your game files

Copy these files from AReyeP's downloads into `run`, renamed as shown. Both
SR mapsets use `.RIP`, and End of Destiny and Wolfendoom use `.WL6` (which
would clash with Wolfenstein 3D and each other), so each game gets an
extension of its own:

| Download | Files | Copy as |
|---|---|---|
| `Spearres.zip` (Spear Resurrection, 2001) | `VSWAP.RIP` | `VSWAP.SR` |
| | `GAMEMAPS.RIP` `MAPHEAD.RIP` `AUDIOHED.RIP` `AUDIOT.RIP` `VGAHEAD.RIP` `VGADICT.RIP` `VGAGRAPH.RIP` `HELPART.RIP` | the same names with `.SR1` |
| `SRSDL2.ZIP` (Spear Resurrection SDL, 2011 maps) | `GAMEMAPS.RIP` `MAPHEAD.RIP` `AUDIOHED.RIP` `AUDIOT.RIP` `VGAHEAD.RIP` `VGADICT.RIP` `VGAGRAPH.RIP` | the same names with `.SR2` |
| `EOD_112.ZIP` (End of Destiny v1.12, editor's version) | `VSWAP.WL6` | `VSWAP.EOD` |
| | `GAMEMAPS.WL6` `MAPHEAD.WL6` `AUDIOHED.WL6` `AUDIOT.WL6` `VGAHEAD.WL6` `VGADICT.WL6` `VGAGRAPH.WL6` `SPEAR.EXE` | the same names with `.EOD` |
| `Wolfdoom.zip` (Wolfendoom, 2001) | `VSWAP.WL6` `GAMEMAPS.WL6` `MAPHEAD.WL6` `AUDIOHED.WL6` `AUDIOT.WL6` `VGAHEAD.WL6` `VGADICT.WL6` `VGAGRAPH.WL6` `Helpart.wl6` `Endart1.wl6` … `Endart6.wl6` | the same names with `.WFD` |
| | `Wolfdoom.exe` | `WOLFDOOM.WFD` |

The stage script (step 2) does the same copying for you; it also checks the
VSWAPs and blanks the unused placeholder map slots in each MAPHEAD.

The engine reads the `VSWAP`, `GAMEMAPS` and `MAPHEAD` files directly. The
rest (`AUDIO*`, `VGA*`, `HELPART`, and EoD's palette from `SPEAR.EXE`) is
converted once into `run/AReyeP-data.pk3` by step 3. `WOLF4SDL` there points
at the eod4sdl clone (default `~/Projects/areyep-ref/eod4sdl`); without it,
or without a C++ compiler, the AdLib sound effects are skipped with a warning
and everything else still converts.

## Development

The headless checks and screenshot tools in `tools/` are bash scripts for
Linux: `tools/headless.sh` and `tools/reportall.sh` need `timeout` and
`stdbuf` (coreutils); `tools/shot.sh` needs `gamescope`, `grim` and `hyprctl`
(a Hyprland session); `tools/cases.py` needs `objdump`. Test builds use a
`-test` suffix so they never replace the packs you play.

## What's in this repo

- The mod itself, packed as `AReyeP.pk3`: `ZScript.zs` and `Scripts/AReyeP/`
  (`AReyePExtension` is the hook into the TC), the games' TileCodes and
  GraphicMaps tables under `Data/`, and its own MAPINFO, MENUDEF, LOCKDEFS
  and other definition files.
- `tools/`: staging, asset conversion, building, and headless test runs
  (test builds use a `-test` suffix: `tools/headless.sh`, `tools/shot.sh`).
- `docs/`: [PORTING.md](docs/PORTING.md) covers how the port works, what's
  done and the roadmap.

## License

The mod and its tools (everything in this repo) are licensed under the
[GNU General Public License v3.0](LICENSE).

That covers this repo only. The Wolf3D TC it plugs into is AFADoomer's, under
the MIT license in its source files, and the games' data (Spear Resurrection,
End of Destiny and Wolfendoom) belongs to AReyeP and MCS: it isn't included
here, and you supply your own copies.

## Credits

- **Spear Resurrection** (2001) and **Spear: End of Destiny** (2004/2006) —
  AReyeP (Steve Walley) and MCS Amsterdam, with BrotherTank; https://www.areyep.com/.
  This project uses their games as its base, with credit, as AReyeP asked.
- **Wolfendoom** (2001) — AReyeP, with MCS Amsterdam.
- Spear Resurrection SDL / 10th Anniversary Edition — Andy Nonymous (SDL code), Ack (two new levels).
- EOD4SDL recreation (behaviour reference) — Kyle Albert.
- Wolf3D TC 3.0 — AFADoomer; see `Credits.txt` in the TC for its own credits.
- Wolfenstein 3D / Spear of Destiny — id Software, FormGen.
