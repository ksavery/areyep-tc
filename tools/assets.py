"""Build run/AReyeP-data.pk3 from the staged AReyeP data (never committed).

Contents:
  Graphics/SR/<chunk>.png     SR VGAGRAPH pictures (HUD, menus, screens)
  TEXTURES.SR                 short names for the SR HUD pieces
  Music/SRMUS<nn>.lmp         SR's AdLib songs, wrapped like the TC's (ADLIB\\1 header, 32-bit length, IMF data)
  MAPINFO.SR                  SR1/SR2 level names, music and progression
  Data/SR/Help.txt            Read This! (HELPART.SR1)
  Sounds/SR/SRDSnnn.wav       SR's digitized sounds (VSWAP.SR, 8-bit 7042 Hz)
  Sounds/SR/SRALnnn.wav       SR's AdLib sound effects, rendered by tools/adlibsfx.cpp
  SNDINFO.SR                  TC sound names -> SR sounds, plus sr/soundNN
  Graphics/EOD/ (with STARSKY.png, MCS's star sky, and CLOUDS.png), TEXTURES.EOD, Music/EODMUS<nn>.lmp, MAPINFO.EOD,
  Sounds/EOD/, SNDINFO.EOD    the same for End of Destiny (eod/<name> sounds)

The AdLib renderer is compiled from tools/adlibsfx.cpp against the fmopl.cpp
of a local Wolf4SDL-based checkout (default ~/Projects/areyep-ref/eod4sdl,
or $WOLF4SDL); without one the AdLib sounds are skipped.

usage: assets.py STAGED-DIR [OUT]
"""
import io
import re
import os
import shutil
import struct
import subprocess
import tempfile
import wave
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import unlzexe
import vgagraph
from tcpath import TC
import wolfdata
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# SR VGAGRAPH chunks used by the status bar (identified from contact sheets)
SR_HUD = {
    "SRBAR": 90,
    "SRNOKEY": 105, "SRKEY1": 106, "SRKEY2": 107, "SRKEY3": 150, "SRKEY4": 151,
    "SRNUMBL": 108,
    **{"SRNUM%d" % n: 109 + n for n in range(10)},
    **{"SRFST%d%d" % (h, v): 119 + h * 3 + v for h in range(7) for v in range(3)},
    "SRFDEAD0": 140, "SRFEVL": 141, "SRFGOD0": 142, "SRFGOD1": 143, "SRFGOD2": 144,
    **{"SRWPN%d" % n: 151 + n for n in range(1, 6)},  # weapon strip with slot n lit
    "SRWPN0": 157,                                    # nothing lit
}

# Full-screen pictures: sign-on (shown while "loading"), credits, and the title,
# which is two pictures (79 over 80) drawn with TITLEPALETTE (chunk 161)
SR_SCREENS = {"SRSTART": 86, "SRCREDIT": 92, "SRPRES": 91}
SR_TITLE_PARTS, SR_TITLE_PALETTE = (79, 80), 161

# Intermission pictures and the big stats font: TC texture names -> SR chunks.
# These replace the TC's Wolf3D versions outright while the mod is loaded.
SR_INTERMISSION = {
    "BREATHE0": 36, "BREATHE1": 77, "BJFINAL": 78,  # "BJ was here!" (2 frames), B.J. with the MCS cannon
    "WOLF58": 37, "WOLF37": 48, "WOLF33": 75, "WOLF39": 76,  # : % ! '
    **{"WOLF%d" % (48 + n): 38 + n for n in range(10)},      # 0-9
    **{"WOLF%d" % (65 + n): 49 + n for n in range(26)},      # A-Z
}

# Menu art: the TC's Spear menu names point at Spear VGAGRAPH chunks, and SR and
# EoD keep those chunk numbers for these. EoD's own (purple headings) go in as
# EOD_<name>, which AReyePGame.MenuTex picks while EoD is the game; its option
# markers sit two chunks earlier (EOD_MENU_MOVED)
SR_MENU = {
    "MENUBLUE": 3, "M_SCNTRL": 4, "M_SCUSTO": 9, "M_SOPTIONS": 15, "M_SMENU": 16,
    "M_SKILL": 20, **{"SSKILL%d" % n: 20 + n for n in range(1, 5)}, "M_SLOADG": 27, "M_SSAVEG": 28,
    "M_SSELC0": 7, "M_SSELC1": 8,  # option markers, grey where Spear's are blue
}

EOD_MENU_MOVED = {"M_SSELC0": 5, "M_SSELC1": 6}

SR_MUSIC_START = 243  # STARTMUSIC: chunk = songs[map] + 243 (MCS's StartMusic)

# songs[] from SPEAR.EXE (DS:0x10b2) and both SDL builds: song per map slot
SR_SONGS = [10, 11, 23, 20, 18, 9, 21, 7, 16, 22, 8, 4, 12, 2, 24, 14, 5, 15, 19, 25, 1, 13, 17]
# MCS's level change code (image 0xc977): secret elevators and where secret levels return
SR_SECRET_EXIT = {2: 18, 12: 19, 9: 21, 15: 22}
SR_SECRET_RETURN = {18: 3, 19: 13, 21: 10, 22: 16}
# parTimes (minutes) per slot: SPEAR.EXE/SOD2SDL.EXE and SOD2SDL2.EXE; 0 = "??:??"
SR_PAR = {
    "SR1": [1.0, 4.0, 8.0, 5.75, 0, 6.0, 6.5, 6.5, 4.75, 0, 5.75, 5.0, 6.75, 4.75, 0, 5.75, 4.75, 0, 0, 0, 0, 0],
    "SR2": [2.0, 3.75, 4.25, 3.75, 0, 6.75, 6.0, 6.0, 7.0, 0, 6.75, 7.0, 7.25, 6.25, 0, 7.0, 7.5, 0, 0, 0, 0, 0],
}
SR_SPEAR_MAP, SR_FINAL_MAP = 17, 20  # the Spear's level leads to the Afterlife, which ends the game


# DigiMap from SPEAR.EXE (image 0x392a4): SR sound number -> VSWAP digi sound.
# Sounds 0-82 follow Spear/EoD's soundnames (eod4sdl audiosod.h); 83+ are SR's.
SR_DIGIMAP = {
    21: 0, 19: 2, 18: 3, 26: 4, 24: 5, 11: 6, 51: 7, 59: 8, 60: 9, 29: 10, 22: 11, 16: 12,
    46: 13, 52: 15, 56: 16, 58: 17, 61: 18, 40: 22, 50: 23, 25: 23, 53: 24, 57: 25, 54: 26,
    55: 27, 63: 28, 38: 38, 41: 1, 10: 14, 66: 19, 67: 20, 68: 21, 70: 29, 71: 30, 72: 31,
    73: 32, 74: 33, 75: 34, 76: 35, 65: 36, 77: 37, 79: 39,
    **{s: s - 41 for s in range(81, 101)},
}

# TC sound names whose Lost Episodes/SoD sample slot SR shares (from SndInfo.txt:
# LSNDnnnn/SSNDnnnn are SoD-numbered digi sounds; the Wolf names are their twins)
SR_TC_SOUNDS = {
    "brown/sight": 0, "green/sight": 0, "dog/sight": 1, "doberman/sight": 1,
    "door/classic/close": 2, "door/close2": 2, "door/classic/open": 3, "door/open2": 3,
    "weapons/wmachinegun": 4, "weapons/wmachinegun2": 4, "weapons/wpistol": 5, "weapons/wpistol2": 5,
    "weapons/wchaingun": 6, "weapons/wchaingun2": 6, "blue/sight": 7, "black/sight": 7,
    "shots/burst": 9, "shots/burst2": 9, "brown/die1": 10, "green/die1": 10, "brown/die2": 11, "green/die2": 11,
    "door/classic/secret": 13, "door/secret2": 13, "dog/death": 14, "doberman/death": 14,
    "nazi/die": 15, "nazi/die2": 15, "blue/death": 16, "black/death": 16,
    "shots/single": 17, "shots/single2": 17, "slurpie": 18, "slurpie2": 18,
    "white/sight": 19, "white2/sight": 19, "white/death": 20, "white2/death": 20,
    "dog/attack": 21, "doberman/attack": 21, "switches/elevator": 22, "switches/elevator2": 22,
    "brown/die4": 23, "green/die3": 23, "green/die4": 23, "brown/die5": 24, "green/die5": 24,
    "brown/die6": 26, "green/die6": 26, "brown/die7": 27, "green/die7": 27, "brown/die8": 28, "green/die8": 28,
    "trans/sight": 29, "trans/death": 30, "wilhelm/sight": 31, "wilhelm/death": 32, "uber/death": 33,
    "dk/sight": 34, "dk/death": 35, "aod/sight": 36, "aod/death": 37,
    "pickups/cgunsod": 38, "spear/pickup": 39, "column/break": 21,
}

# TC pickup sound names -> the SR sound number MCS's GetBonus plays for that item
SR_TC_PICKUPS = {
    "pickups/key": 12, "pickups/cross": 36, "pickups/cup": 35, "pickups/chest": 37, "pickups/crown": 45,
    "pickups/ammo": 31, "pickups/ammobox": 64, "pickups/mgun": 30, "pickups/cgun": 38,
    "pickups/food": 33, "pickups/medkit": 34, "pickups/life": 44,
}

SR_ADLIB_START, SR_SOUNDS = 81, 81  # STARTADLIBSOUNDS = NUMSOUNDS in SR1's AUDIOT

# --- End of Destiny (EoD's SPEAR.EXE, editor's version 1.12) ---

# VGAGRAPH: the same picture numbering as SR's for the status bar pieces
EOD_HUD = {
    "EODBAR": 90,
    "EODNOKEY": 105, "EODKEY1": 106, "EODKEY2": 107, "EODKEY3": 150, "EODKEY4": 151,
    "EODNUMBL": 108,
    **{"EODNUM%d" % n: 109 + n for n in range(10)},
    **{"EOFST%d%d" % (h, v): 119 + h * 3 + v for h in range(7) for v in range(3)},
    "EOFDEAD0": 140, "EOFEVL": 141, "EOFGOD0": 142, "EOFGOD1": 143, "EOFGOD2": 144,
    **{"EODWPN%d" % n: 153 + n for n in range(8)},  # knife pistol MG Mk3 Mk4 rifle launcher Spear
    "EODMEDKT": 161,
}
EOD_SCREENS = {"EODPRES": 91, "EODCREDT": 92, "EODEND1": 81, "EODEND2": 82, "EODEND3": 83, "EODEND4": 84}
EOD_TITLE_PARTS, EOD_TITLE_PALETTE = (79, 80), 163

EOD_MUSIC_START = 315  # STARTMUSIC: 3 * 105 sounds
# songs[] (DS:0x10EA): song per map slot (StartMusic: songs[mapon] + 315)
EOD_SONGS = [37, 19, 20, 21, 22, 7, 23, 12, 8, 24, 25, 26, 27, 13, 6, 3, 5, 28, 29, 12, 21, 23, 20, 28, 11, 1, 30, 31, 36, 14, 10, 32, 33, 34, 9, 35, 25, 38]
# parTimes (DS:0x0A08, minutes; 0 = "??:??")
EOD_PAR = [0.75, 1.75, 3.0, 3.0, 4.0, 5.0, 0, 6.0, 5.5, 7.0, 4.0, 0, 6.0, 7.25, 7.0, 3.75, 6.5, 5.5, 6.5, 5.75, 2.5, 0, 4.5, 5.0] + [0] * 14
# Progression: eod4sdl's per-level flags (secret level / back to level), with the
# secret elevators where the maps have them (the 0x6B floor beside the switch)
EOD_SECRET_EXIT = {1: 26, 7: 27, 9: 28, 11: 35, 14: 29, 17: 36, 20: 37, 22: 33, 27: 34, 28: 30, 29: 31, 36: 32}
EOD_SECRET_RETURN = {26: 2, 27: 8, 28: 10, 29: 15, 30: 10, 31: 15, 32: 18, 33: 23, 34: 8, 35: 12, 36: 18, 37: 21}
EOD_SPEAR_MAP, EOD_FINAL_MAP = 24, 25  # the Spear (Heinrich) leads to Hell on Earth, which ends the game

# Digitized sounds by VSWAP digi number: EoD keeps Spear's order (and SR's) for
# 0-39 and adds its own after (names matched against eod4sdl's VSWAP by PCM)
EOD_DIGI_NAMES = [
    "halt", "bombtrigger", "closedoor", "opendoor", "atkmachinegun", "atkpistol", "atkgatling", "schutzad",
    "bossfire", "ssfire", "deathscream1", "deathscream2", "takedamage", "pushwall", "longexplosion", "ahhhg",
    "leben", "nazifire", "slurpie", "spion", "neinsovas", "columnbreak", "leveldone", "deathscream4",
    "deathscream5", "deathscream6", "deathscream7", "deathscream8", "deathscream9", "grausight", "graudeath",
    "robotsight", "robotdeath", "clonebossdeath", "baronsight", "barondeath", "angelsight", "angeldeath",
    "getgatling", "getspear", "emptyclip", "landmine", "radiocast", "doorlocked", "barrelexp", "yeah", "gong",
    "gatling", "fart", "mk4", "swish", "toilet", "rlaunch", "ottosight", "ottodeath", "heinrichsight",
    "heinrichdeath", "turretfire", "deathscream10", "yourang", "silenced", "closewooddr", "openwooddr",
    "closenormaldr", "opennormaldr",
]
EOD_ADLIB_START, EOD_ADLIB_SOUNDS = 105, 80  # AdLib sounds 0-79 are Spear's (80+ are empty)
# EoD's game palette differs from Spear's in 34 entries: it is the 768-byte VGA
# table in SPEAR.EXE starting with Spear's first colours
EOD_PALETTE_START = bytes([0, 0, 0, 0, 0, 42, 0, 42, 0, 0, 42, 42])

# Articles (Wolf3D ^P/^C/^G text): the ending, and the level stories 1-16 (170 + n)
EOD_END_TEXT, EOD_LEVEL_TEXTS = 169, range(171, 187)
EOD_HELP_TEXT = 170  # Read This!: story, manual and credits


def adlib_sounds(staged, ext="SR1", start=SR_ADLIB_START, count=SR_SOUNDS):
    """Render a game's AdLib sound effects with tools/adlibsfx; {sound number: wav bytes}."""
    ref = Path(os.environ.get("WOLF4SDL", Path.home() / "Projects/areyep-ref/eod4sdl"))
    if not (ref / "fmopl.cpp").exists():
        print(f"warning: no fmopl.cpp under {ref}; skipping AdLib sounds")
        return {}
    exe = ROOT / "run" / ("adlibsfx.exe" if os.name == "nt" else "adlibsfx")
    src = ROOT / "tools" / "adlibsfx.cpp"
    if not exe.exists() or exe.stat().st_mtime < src.stat().st_mtime:
        cxx = shutil.which(os.environ.get("CXX", "g++"))
        if not cxx:
            print("warning: no C++ compiler (g++, or $CXX); skipping AdLib sounds")
            return {}
        subprocess.run([cxx, "-O2", "-w", f"-I{ref}", str(src), str(ref / "fmopl.cpp"), "-o", str(exe)], check=True)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([str(exe), str(staged / f"AUDIOHED.{ext}"), str(staged / f"AUDIOT.{ext}"),
                        str(start), str(count), tmp], check=True, stdout=subprocess.DEVNULL)
        return {int(p.stem[5:]): p.read_bytes() for p in Path(tmp).glob("ADLIB*.wav")}


def digi_sounds(vs):
    """VSWAP digitized sounds as raw 8-bit unsigned PCM, indexed by digi number."""
    info = vs.chunk(vs.chunks - 1)
    out = []
    for i in range(len(info) // 4):
        start, length = struct.unpack_from("<2H", info, 4 * i)
        if start == 0xFFFF:
            break
        data, page = b"", vs.sound_start + start
        while len(data) < length and page < vs.chunks - 1:
            data += vs.chunk(page)
            page += 1
        out.append(data[:length])
    return out


def wav(pcm, rate=7042):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(rate)
        w.writeframes(pcm)
    return buf.getvalue()


def sr_sndinfo(count, adlib):
    lines = ["// Generated by tools/assets.py: SR sounds (digitized where MCS's DigiMap has one, else AdLib)\n"]
    for s in sorted(set(SR_DIGIMAP) | set(adlib)):
        if SR_DIGIMAP.get(s, count) < count:
            lines.append("sr/sound%d SRDS%03d\n" % (s, SR_DIGIMAP[s]))
        elif s in adlib:
            lines.append("sr/sound%d SRAL%03d\n" % (s, s))
    for name, d in SR_TC_SOUNDS.items():
        if d < count:
            lines.append("%s SRDS%03d\n" % (name, d))
    for name, s in SR_TC_PICKUPS.items():
        lines.append("$alias %s sr/sound%d\n" % (name, s))
    lines.append("$alias sr/thunder sr/sound83\n")
    return "".join(lines)


def sr_mapinfo(staged, ext, base):
    maps = wolfdata.read_maps(staged.joinpath(f"MAPHEAD.{ext}").read_bytes(), staged.joinpath(f"GAMEMAPS.{ext}").read_bytes())
    lump = lambda slot: "%s_%02d" % (ext, slot + 1)
    out = [f"// {ext}: generated by tools/assets.py\n"]
    for m in maps:
        slot = m.index
        if slot == SR_FINAL_MAP:
            nxt = 'EndSequence, "EndEpisode"'
        elif slot == SR_SPEAR_MAP:
            nxt = lump(SR_FINAL_MAP)
        elif slot in SR_SECRET_RETURN:
            nxt = lump(SR_SECRET_RETURN[slot])
        else:
            nxt = lump(slot + 1)
        name = m.name.replace('"', "'")
        par = SR_PAR[ext][slot] if slot < len(SR_PAR[ext]) else 0
        out.append(f'\nmap {lump(slot)} "{name}"\n{{\n\tlevelnum = {base + slot + 1}\n\tmusic = SRMUS{SR_SONGS[slot]:02d}\n\tpar = {int(par * 60)}\n\tnext = {nxt}\n')
        if slot in SR_SECRET_EXIT:
            out.append(f"\tsecretnext = {lump(SR_SECRET_EXIT[slot])}\n")
        if slot == SR_SPEAR_MAP:
            out.append("\tnointermission\n")
        out.append("}\n")
    return "".join(out)


def eod_sndinfo(count, adlib):
    lines = ["// Generated by tools/assets.py: End of Destiny sounds\n"]
    for d, name in enumerate(EOD_DIGI_NAMES[:count]):
        lines.append("eod/%s EODDS%03d\n" % (name, d))
    for s in sorted(adlib):
        lines.append("eod/sound%d EODAL%03d\n" % (s, s))
    # A_DeathScream (image 0x1a46f): guards, officers and SS pick one of seven
    lines.append("$random eod/nazideath { eod/deathscream1 eod/deathscream2 eod/deathscream4 eod/deathscream5 eod/deathscream7 eod/deathscream8 eod/deathscream9 }\n")
    return "".join(lines)


def eod_mapinfo(staged):
    maps = wolfdata.read_maps(staged.joinpath("MAPHEAD.EOD").read_bytes(), staged.joinpath("GAMEMAPS.EOD").read_bytes())
    lump = lambda slot: "EOD_%02d" % (slot + 1)
    out = ["// EOD: generated by tools/assets.py\n"]
    for m in maps:
        slot = m.index
        if slot == EOD_FINAL_MAP:
            nxt = 'EndSequence, "EndEpisode"'
        elif slot in EOD_SECRET_RETURN:
            nxt = lump(EOD_SECRET_RETURN[slot])
        else:
            nxt = lump(slot + 1)
        name = m.name.replace('"', "'")
        out.append(f'\nmap {lump(slot)} "{name}"\n{{\n\tlevelnum = {4000 + slot + 1}\n\tmusic = EODMUS{EOD_SONGS[slot]:02d}\n\tpar = {int(EOD_PAR[slot] * 60)}\n\tnext = {nxt}\n')
        if slot in EOD_SECRET_EXIT:
            out.append(f"\tsecretnext = {lump(EOD_SECRET_EXIT[slot])}\n")
        if slot == EOD_SPEAR_MAP:
            out.append(f"\tsecretnext = {lump(EOD_FINAL_MAP)}\n\tnointermission\n")
        out.append("}\n")
    return "".join(out)


STATUSBAR = 90  # SRBAR / EODBAR


def clear_border(im):
    """The status bar's flat grey frame, flooded in from its edges, made clear so
    the rocky backdrop shows round the panels on a wide screen."""
    im = im.convert("RGBA")
    w, h = im.size
    edge = im.getpixel((0, 0))
    todo = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or im.getpixel((x, y)) != edge:
            continue
        seen.add((x, y))
        im.putpixel((x, y), (0, 0, 0, 0))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def write_pictures(z, vg, pal, family, titleparts, titlepalette):
    for i in range(len(vg.picsizes)):
        buf = io.BytesIO()
        pic = vg.picture(i + 3, pal)
        (clear_border(pic) if i + 3 == STATUSBAR else pic).save(buf, "PNG")
        z.writestr("Graphics/%s/%04d.png" % (family, i + 3), buf.getvalue())

    raw = vg.chunk(titlepalette)
    titlepal = [tuple(min(255, v * 255 // 63) for v in raw[i:i + 3]) for i in range(0, 768, 3)]
    title = Image.new("RGB", (320, 200))
    y = 0
    for chunk in titleparts:
        part = vg.picture(chunk, titlepal)
        title.paste(part, (0, y))
        y += part.height
    buf = io.BytesIO()
    title.save(buf, "PNG")
    z.writestr("Graphics/%s/TITLE.png" % family, buf.getvalue())


def eod_palette(staged):
    """EoD's palette as [(r, g, b)] and as a JASC .pal for the TC's VSWAP reader."""
    image = unlzexe.unpack(staged.joinpath("SPEAR.EOD").read_bytes())
    at = image.find(EOD_PALETTE_START)
    if at < 0:
        raise SystemExit("no palette found in SPEAR.EOD")
    pal = [tuple(v * 255 // 63 for v in image[at + 3 * k:at + 3 * k + 3]) for k in range(256)]
    jasc = "JASC-PAL\n0100\n256\n" + "".join("%d %d %d\n" % c for c in pal)
    return pal, jasc


# DrawStarSky (EoD image 0x4faa): the sky MCS draws in place of the ceiling on
# sky levels. 300 points x, z in -16384..16383 and y in 1024..33791, kept low
# enough to show in a full-size view; each is drawn in palette 15 + distance /
# 1024 (nearer brighter, none past 16384), with the 10x10 moon (segment 0x345a)
# hung at 45 degrees. Laid out here as a 2048x256 sky, 5.7 pixels a degree (the
# original's 320 pixels span 64 degrees) with the horizon at row 230.
EOD_MOON = 0x345A0
STARSKY_W, STARSKY_H, STARSKY_HORIZON = 2048, 256, 230


def eod_starsky(image, pal):
    import math
    import random

    rnd = random.Random(626)
    sky = Image.new("RGB", (STARSKY_W, STARSKY_H), pal[0])
    perdeg = STARSKY_W / 360
    for _ in range(300):
        x, z = 16384 - rnd.randrange(32768), 16384 - rnd.randrange(32768)
        length = math.hypot(x, z) or 1
        for _ in range(50):  # Init3DPoints: below the top of an 80-pixel half view
            y = 1024 + rnd.randrange(32768)
            if y * 256 / length < 80:
                break
        shade = int(length) >> 10
        if shade > 15:
            continue
        px = int(math.degrees(math.atan2(x, z)) % 360 * perdeg)
        py = int(STARSKY_HORIZON - math.degrees(math.atan2(y, length)) * perdeg)
        if 0 <= py < STARSKY_H:
            sky.putpixel((px, py), pal[15 + shade])

    moon = image[EOD_MOON:EOD_MOON + 100]
    mx = int(45 * perdeg) - 5
    my = int(STARSKY_HORIZON - math.degrees(math.atan2(49.5, 256)) * perdeg) - 5
    for j in range(10):
        for i in range(10):
            if moon[j * 10 + i]:
                sky.putpixel((mx + i, my + j), pal[moon[j * 10 + i]])

    buf = io.BytesIO()
    sky.save(buf, "PNG")
    return buf.getvalue()


# Kyle Albert's eod4sdl drifts Wolf4SDL's cloud sky over the stars (seed 626,
# colour map 31-28 then 255-253, of which only the greys are drawn): a 256x256
# plasma, smoothed twice, wrapping in both directions. Generated the same way
# with MSVC's rand() and tiled four times round the sky; clear between clouds.
def eod_clouds(pal):
    state = [626]

    def rand():
        state[0] = (state[0] * 214013 + 2531011) & 0xFFFFFFFF
        return (state[0] >> 16) & 0x7FFF

    skyc = bytearray(65536)

    def split(size, x1, y1, x2, y2):
        if size == 1:
            return
        h = size // 2

        def mid(at, a, b):
            if not skyc[at]:
                skyc[at] = ((skyc[a] + skyc[b]) // 2 + rand() % (size * 2) - size) & 0xFF or 1

        mid((x1 + h) * 256 + y1, x1 * 256 + y1, (x2 & 0xFF) * 256 + y1)
        mid((x1 + h) * 256 + (y2 & 0xFF), x1 * 256 + (y2 & 0xFF), (x2 & 0xFF) * 256 + (y2 & 0xFF))
        mid(x1 * 256 + y1 + h, x1 * 256 + y1, x1 * 256 + (y2 & 0xFF))
        mid((x2 & 0xFF) * 256 + y1 + h, (x2 & 0xFF) * 256 + y1, (x2 & 0xFF) * 256 + (y2 & 0xFF))
        corners = skyc[x1 * 256 + y1] + skyc[(x2 & 0xFF) * 256 + y1] + skyc[x1 * 256 + (y2 & 0xFF)] + skyc[(x2 & 0xFF) * 256 + (y2 & 0xFF)]
        skyc[(x1 + h) * 256 + y1 + h] = (corners // 4 + rand() % (size * 2) - size) & 0xFF
        split(h, x1, y1 + h, x1 + h, y2)
        split(h, x1 + h, y1, x2, y1 + h)
        split(h, x1 + h, y1 + h, x2, y2)
        split(h, x1, y1, x1 + h, y1 + h)

    skyc[0] = rand() % 256
    split(256, 0, 0, 256, 256)
    for _ in range(2):
        for i in range(256):
            for j in range(256):
                val = -skyc[j * 256 + i]
                for m in range(3):
                    for n in range(3):
                        val += skyc[((j + n - 1) & 0xFF) * 256 + ((i + m - 1) & 0xFF)]
                skyc[j * 256 + i] = (val >> 3) & 0xFF

    colours = [31, 30, 29, 28, 255, 254, 253]
    tile = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for i in range(256):
        for j in range(256):
            c = colours[skyc[i * 256 + j] * len(colours) // 256]
            if c <= 0x2F:
                tile.putpixel((j, i), pal[c] + (255,))
    sky = Image.new("RGBA", (1024, 256))
    for t in range(4):
        sky.paste(tile, (t * 256, 0))
    buf = io.BytesIO()
    sky.save(buf, "PNG")
    return buf.getvalue()


def build_eod(z, staged, pal):
    pal, jasc = eod_palette(staged)
    z.writestr("Data/Palettes/EoD.pal", jasc)
    z.writestr("Graphics/EOD/CLOUDS.png", eod_clouds(pal))
    z.writestr("Graphics/EOD/STARSKY.png", eod_starsky(unlzexe.unpack(staged.joinpath("SPEAR.EOD").read_bytes()), pal))
    vg = vgagraph.VGAGraph(*(staged.joinpath(f"{n}.EOD").read_bytes() for n in ("VGAHEAD", "VGAGRAPH", "VGADICT")))
    write_pictures(z, vg, pal, "EOD", EOD_TITLE_PARTS, EOD_TITLE_PALETTE)
    tex = ["// Generated by tools/assets.py from the staged EoD VGAGRAPH\n"]
    tex.append('Graphic EODTITLE, 320, 200 { Patch "Graphics/EOD/TITLE.png", 0, 0 }\n')
    tex.append('Graphic GAME_EOD, 320, 200 { XScale 7.5 YScale 7.5 Patch "Graphics/EOD/TITLE.png", 0, 0 }\n')  # game picker icon
    tex.append('Texture EODSKY, %d, %d { XScale 2 YScale 2 Patch "Graphics/EOD/STARSKY.png", 0, 0 }\n' % (STARSKY_W, STARSKY_H))
    tex.append('Texture EODCLOUD, 1024, 256 { YScale 2 Patch "Graphics/EOD/CLOUDS.png", 0, 0 }\n')
    for name, chunk in list(EOD_SCREENS.items()) + list(EOD_HUD.items()):
        w, h = vg.picsizes[chunk - 3]
        tex.append('Graphic %s, %d, %d { Patch "Graphics/EOD/%04d.png", 0, 0 }\n' % (name, w, h, chunk))
    for name, chunk in SR_MENU.items():
        chunk = EOD_MENU_MOVED.get(name, chunk)
        w, h = vg.picsizes[chunk - 3]
        offset = " Offset 92, 0" if name == "M_SKILL" else ""
        tex.append('Texture EOD_%s, %d, %d {%s Patch "Graphics/EOD/%04d.png", 0, 0 }\n' % (name, w, h, offset, chunk))
    for i in range(len(vg.picsizes)):  # every picture, for the articles' ^G
        w, h = vg.picsizes[i]
        tex.append('Graphic EODV%04d, %d, %d { Patch "Graphics/EOD/%04d.png", 0, 0 }\n' % (i + 3, w, h, i + 3))
    z.writestr("TEXTURES.EOD", "".join(tex))

    article = lambda c: vg.chunk(c).decode("latin1").replace("\r", "").split("^E")[0]
    z.writestr("Data/EoD/End.txt", article(EOD_END_TEXT))
    z.writestr("Data/EoD/Help.txt", article(EOD_HELP_TEXT))
    for n, c in enumerate(EOD_LEVEL_TEXTS, 1):
        z.writestr("Data/EoD/Text%02d.txt" % n, article(c))

    songs = music_chunks(staged.joinpath("AUDIOHED.EOD").read_bytes(), staged.joinpath("AUDIOT.EOD").read_bytes(), EOD_MUSIC_START)
    for n, data in enumerate(songs):
        z.writestr("Music/EODMUS%02d.lmp" % n, imf_lump(data))
    z.writestr("MAPINFO.EOD", eod_mapinfo(staged))

    digis = digi_sounds(wolfdata.VSwap(staged.joinpath("VSWAP.EOD").read_bytes()))
    for d, pcm in enumerate(digis):
        z.writestr("Sounds/EOD/EODDS%03d.wav" % d, wav(pcm))
    adlib = adlib_sounds(staged, "EOD", EOD_ADLIB_START, EOD_ADLIB_SOUNDS)
    for s, data in adlib.items():
        z.writestr("Sounds/EOD/EODAL%03d.wav" % s, data)
    z.writestr("SNDINFO.EOD", eod_sndinfo(len(digis), adlib))
    return len(vg.picsizes), len(songs), len(digis), len(adlib)


def tc_wolf_floors():
    """The TC's Wolfenstein 3D floors from its MapInfo.txt: {(episode, floor):
    {property: value}}, floor 10 being the secret floor (the TC's EnL0)."""
    text = (TC / "MapInfo.txt").read_text()
    floors = {}
    for m in re.finditer(r'^map E(\d)L(\d) "[^"]*"\s*\{(.*?)^\}', text, re.M | re.S):
        props = {}
        for line in m.group(3).splitlines():
            if "=" in line:
                key, value = (x.strip() for x in line.split("=", 1))
                props[key.lower()] = value
        floors[(int(m.group(1)), int(m.group(2)) or 10)] = props
    return floors


def wd_mapinfo(staged):
    """Wolfendoom's 60 floors: Wolf3D's six episodes of nine floors and a secret
    one. WOLFDOOM.EXE keeps Wolf3D's progression, par times and ceilings, so each
    floor follows the TC's matching Wolf3D floor, with Wolfendoom's own name and
    levelnum 5000 + episode * 100 + floor (Scripts/AReyeP/Games.zs)."""
    maps = wolfdata.read_maps(staged.joinpath("MAPHEAD.WFD").read_bytes(), staged.joinpath("GAMEMAPS.WFD").read_bytes())
    floors = tc_wolf_floors()
    lump = lambda ep, fl: "WD_E%dL%d" % (ep, fl % 10)
    rename = lambda v: re.sub(r"\bE(\d)L(\d)\b", lambda m: "WD_E%sL%s" % (m.group(1), m.group(2)), v)
    out = ["// WD: generated by tools/assets.py from the TC's Wolfenstein 3D floors\n"]
    for m in maps:
        ep, fl = m.index // 10 + 1, m.index % 10 + 1
        props = floors[(ep, fl)]
        name = m.name.replace('"', "'")
        out.append(f'\nmap {lump(ep, fl)} "{name}"\n{{\n\tlevelnum = {5000 + ep * 100 + fl}\n')
        for key in ("music", "intermusic", "par", "next", "secretnext"):
            if key in props:
                out.append(f"\t{key} = {rename(props[key])}\n")
        out.append("}\n")
    return "".join(out)


def build_wd(z, staged):
    """Wolfendoom's data: so far its map list (names, progression, par)."""
    z.writestr("MAPINFO.WFD", wd_mapinfo(staged))
    return 60


def music_chunks(head, audiot, start):
    offs = struct.unpack("<%dI" % (len(head) // 4), head)
    return [audiot[offs[i]:offs[i + 1]] for i in range(start, len(offs) - 1)]


def imf_lump(chunk):
    """An AUDIOT song (16-bit length, then IMF data) in the TC's wrapping: ZMusic's
    "ADLIB" header, then a 32-bit length."""
    length = struct.unpack("<H", chunk[:2])[0]
    return b"ADLIB\x01\x00\x00\x01" + struct.pack("<I", length) + chunk[2:]


def main():
    staged = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "run" / "AReyeP-data.pk3"
    pal = vgagraph.load_palette(TC / "Data/Palettes/Spear.pal")

    vg = vgagraph.VGAGraph(*(staged.joinpath(f"{n}.SR1").read_bytes() for n in ("VGAHEAD", "VGAGRAPH", "VGADICT")))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for i in range(len(vg.picsizes)):
            buf = io.BytesIO()
            pic = vg.picture(i + 3, pal)
            (clear_border(pic) if i + 3 == STATUSBAR else pic).save(buf, "PNG")
            z.writestr("Graphics/SR/%04d.png" % (i + 3), buf.getvalue())

        raw = vg.chunk(SR_TITLE_PALETTE)
        titlepal = [tuple(min(255, v * 255 // 63) for v in raw[i:i + 3]) for i in range(0, 768, 3)]
        title = Image.new("RGB", (320, 200))
        y = 0
        for chunk in SR_TITLE_PARTS:
            part = vg.picture(chunk, titlepal)
            title.paste(part, (0, y))
            y += part.height
        buf = io.BytesIO()
        title.save(buf, "PNG")
        z.writestr("Graphics/SR/TITLE.png", buf.getvalue())

        tex = ["// Generated by tools/assets.py from the staged SR VGAGRAPH\n"]
        tex.append('Graphic SRTITLE, 320, 200 { Patch "Graphics/SR/TITLE.png", 0, 0 }\n')
        tex.append('Graphic GAME_SR, 320, 200 { XScale 7.5 YScale 7.5 Patch "Graphics/SR/TITLE.png", 0, 0 }\n')  # game picker icon
        for name, chunk in SR_INTERMISSION.items():
            w, h = vg.picsizes[chunk - 3]
            tex.append('Texture %s, %d, %d { Patch "Graphics/SR/%04d.png", 0, 0 }\n' % (name, w, h, chunk))
        for name, chunk in SR_SCREENS.items():
            w, h = vg.picsizes[chunk - 3]
            tex.append('Graphic %s, %d, %d { Patch "Graphics/SR/%04d.png", 0, 0 }\n' % (name, w, h, chunk))
        for name, chunk in SR_MENU.items():
            w, h = vg.picsizes[chunk - 3]
            offset = " Offset 92, 0" if name == "M_SKILL" else ""
            tex.append('Texture %s, %d, %d {%s Patch "Graphics/SR/%04d.png", 0, 0 }\n' % (name, w, h, offset, chunk))
        for name, chunk in SR_HUD.items():
            w, h = vg.picsizes[chunk - 3]
            tex.append('Graphic %s, %d, %d { Patch "Graphics/SR/%04d.png", 0, 0 }\n' % (name, w, h, chunk))
        for i in range(len(vg.picsizes)):  # every picture, for Read This!'s ^G
            w, h = vg.picsizes[i]
            tex.append('Graphic SRV%04d, %d, %d { Patch "Graphics/SR/%04d.png", 0, 0 }\n' % (i + 3, w, h, i + 3))
        z.writestr("TEXTURES.SR", "".join(tex))

        # Read This! (SR keeps it in HELPART, outside VGAGRAPH): story, manual, credits
        helpart = staged.joinpath("HELPART.SR1")
        if helpart.exists():
            z.writestr("Data/SR/Help.txt", helpart.read_bytes().decode("latin1").replace("\r", "").split("^E")[0])

        songs = music_chunks(staged.joinpath("AUDIOHED.SR1").read_bytes(), staged.joinpath("AUDIOT.SR1").read_bytes(), SR_MUSIC_START)
        for n, data in enumerate(songs):
            z.writestr("Music/SRMUS%02d.lmp" % n, imf_lump(data))

        z.writestr("MAPINFO.SR", sr_mapinfo(staged, "SR1", 2000) + sr_mapinfo(staged, "SR2", 3000))

        vs = wolfdata.VSwap(staged.joinpath("VSWAP.SR").read_bytes())
        digis = digi_sounds(vs)
        for d, pcm in enumerate(digis):
            z.writestr("Sounds/SR/SRDS%03d.wav" % d, wav(pcm))
        adlib = adlib_sounds(staged)
        for s, data in adlib.items():
            z.writestr("Sounds/SR/SRAL%03d.wav" % s, data)
        z.writestr("SNDINFO.SR", sr_sndinfo(len(digis), adlib))
        eod = build_eod(z, staged, pal) if staged.joinpath("VGAGRAPH.EOD").exists() else None
        wd = build_wd(z, staged) if staged.joinpath("MAPHEAD.WFD").exists() else None
    if wd:
        print("WD: %d floors" % wd)
    if eod:
        print("EOD: %d pictures, %d songs, %d digitized + %d AdLib sounds" % eod)
    print(f"{out}: {len(vg.picsizes)} pictures, {len(SR_HUD)} HUD names, {len(songs)} songs, {len(digis)} digitized + {len(adlib)} AdLib sounds")


if __name__ == "__main__":
    main()
