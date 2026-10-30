# AReyeP TC — porting notes

Goal: play AReyeP & MCS's **Spear Resurrection** (original 2001 maps and the
2011 SDL new mapset) and **Spear: End of Destiny** in UZDoom, selectable from
one install, reusing everything AFADoomer's Wolf3D TC 3.0 already solves
(modern controls, menus, HUD, automap, rendering).

This repo is a mod: it is packed as `AReyeP.pk3` and loaded on top of an
unmodified TC. The TC lives in its own repo (AFADoomer/Wolf3D-TC-3.0), whose
game-extension hooks (added in AFADoomer/Wolf3D-TC-3.0#82) the mod plugs into.

## How the mod plugs into the TC

- `GameExtension` (TC, `Scripts/Extensions/GameExtension.zs`) is a class mods
  subclass; the TC creates one of each and, at each hook, asks the one that
  claims the game being played. `AReyePExtension` (`Scripts/AReyeP/Extension.zs`)
  claims SR1, SR2 and EOD and answers for them: data sets and map numbers,
  wall actors, flats and sky, door sounds and use, pushwall distance, enemy
  hit points/scores/speeds, the Spear, music, menu look, intro screens,
  status bars, MCS's messages and cheat keys. Before a game is picked it is
  the default extension, so the startup screens and game picker are AReyeP's.
- Everything else is ordinary mod content: actors and event handlers
  (`AddEventHandlers` in MAPINFO), TileCodes/GraphicMaps tables under `Data/`,
  and MAPINFO/MENUDEF/LOCKDEFS/SNDSEQ entries that override the TC's.
- The game picked in the game menu is the TC's `g_modgame` CVar.

## How the TC loads a game (what we build on)

The TC doesn't need pre-converted maps. At startup it reads original data
files straight out of the game folder (`IWADInfo.txt` → `Load`; ours come in
with `-file`, see `tools/args.sh`):

| Piece | Code | What it does |
|---|---|---|
| Maps | `MapHandler.zs` `WolfMapParser` | Parses every `GAMEMAPS.*`/`MAPHEAD.*` pair (Carmack + RLEW), builds the level at runtime in the `Level` map |
| Art | `GraphicsHandler.zs` | Draws every `VSWAP.*` wall/sprite into canvas textures named by `Data/GraphicMaps/<EXT>.txt` (unlisted sprites also get generic `W###A0` names) |
| Wall/door/floor codes | `Data/TileCodes/<EXT>.txt` plane 0 | Texture pattern, door type, keys, specials per tile code |
| Object codes | `Data/TileCodes/<EXT>.txt` plane 1 | `code = "ActorClass", skill, angle, patrolling`, falling back SD3→SD2→SD1→Default |
| Game identity | file extension | `WolfMapParser.Parse`, `ParsedMap.GetGameName`, `GraphicsHandler` all key off the extension |
| Playing | `MapMenu` (`SlideshowMenu.zs`) | Lists parsed maps per data file, starts them via the `initialize:<map>:<file>` net event; progression handled by `MapHandler` |

So each AReyeP game becomes: staged data files under its own extension +
GraphicMaps + TileCodes + ZScript actors for whatever the mod added.

## Source data (user's local copies; never committed)

`tools/stage.py OUTDIR` pulls these from the release archives:

| Extension | Game | Source | Notes |
|---|---|---|---|
| `VSWAP.SR` | SR art (shared) | `Spearres.zip` | identical in DOS, SDL and SDL2 releases (md5 02ec5d44) |
| `*.SR1` | SR original maps | `Spearres.zip` (DOS, TED5) | 23 maps (21 + 2 secret) |
| `*.SR2` | SR 2011 new mapset | `SRSDL2.ZIP` | 23 maps; slots 23–59 are filler, trimmed |
| `*.EOD` | End of Destiny | `EOD_112.ZIP` (editor's version, 2006) | 38 maps (26 + 12 secret); the 2004 release `EoD.zip` has obfuscated map planes and an older VSWAP — don't use it |

Not yet staged: `EOD4SDL_BETA.zip` (Kyle Albert's recreation) re-saved every
map at 128×128 and adds the Xmas 2007–2010 bonus sets — candidate for a later
"EoD Xmas" entry. AReyeP never made a full EoD "new mapset".

VSWAP layout:

| | chunks | walls | sprites | sounds |
|---|---|---|---|---|
| SR | 895 | 200 | 510 | 185 |
| EoD 1.12 | 1084 | 232 | 662 | 190 |

Both use the stock Spear palette (`Data/Palettes/Spear.pal` renders them correctly).

## Behaviour references

There's no public source for MCS's DOS code (SR or EoD), or for Andy
Nonymous's SR SDL port. What we have:

- AReyeP's MapEdit definition files (MAPDATA/OBJDATA from their editor's
  downloads; kept locally in `docs/reference/`, not in the repo): a name for
  **every** object and map code in each game.
- `EODEdit/Map creation notes.txt` (from the editor's-version downloads) —
  AReyeP's design doc for EoD's systems (summarised below).
- `SpearResEdit/Edit.txt` — SR editing notes (teleporter rules, hard-coded
  floor/ceiling changes on teleport).
- [kalbert312/eod4sdl](https://github.com/kalbert312/eod4sdl) — C recreation of
  EoD on Wolf4SDL "to match the original as much as possible"; `wl_game.cpp`
  `ScanInfoPlane`, `wl_act1/2.cpp`, `wl_agent.cpp` are the best reference for
  enemy stats/behaviour. Clone locally to `~/Projects/areyep-ref/` (read only).
- READMEs, manuals and hint books from areyep.com.
- Playing the originals side by side (DOSBox / the SDL exes under Wine).

AReyeP's credit request (EoD notes): add-ons must be credited as yours, and a
new mod built on EoD must say it uses EoD as its base. The README carries the credits.

## Code inventory (from `tools/codes.py`)

Codes the stock TC tables don't define, by game:

- **SR objects:** 19–22 (player starts, 4 directions), 100–103 (teleport
  artefact 1/2 + destinations), 134–137 (standing dogs), 228–231 (dead
  dog/SS/mutant/officer), 260–304 (exploding drum, torches, angel ghost,
  breakable column, ghosts 01–06, boss pedestals full/empty, God Mode artefact,
  berry bushes ±HP, outdoor items/decor, fake teleport, pistol…). SR also
  renames many stock static slots 23–89 (e.g. 46 Death Artefact, 51/75 Multi
  cannon Mk3/Mk4, 76 Blood Key, 77 Elevator Key, 78 Landmine, 80/89 second ammo type).
- **SR map plane:** walls 1–89 → VSWAP pages 2(n−1); doors 90–105 (normal,
  gold/bronze/blood locks, locked elevator, elevator, **rusted**, **wooden**),
  door art at pages 178–199; 106 deaf-guard floor, 107 elevator-to-secret.
- **EoD** is a superset of SR (MCS built it on the SR code): ~150 extra object
  codes (270–354 statics, 380–388, 400–415 fire-shooting walls + switch
  overlays, 416–435 remote pushwalls/markers, 512–523 spawn triggers/targets,
  blocking codes, secret/super-secret triggers, end-level trigger), plus map
  codes 0xF0–0x10F (floor/ceiling texture selectors, used only in row 0).

## EoD systems (from AReyeP's notes)

- **Row 0 is metadata** ("FlexDesign"): (0,0)/(1,0) primary floor/ceiling
  texture, (2,0)/(3,0) secondary (after first teleport), (8–11,0) solid floor/ceiling
  colours, (12–15,0) shading. Never part of the playable map.
- **Switches** (wall texture over a switch-overlay object): toggle fire-shooting
  walls (2 per level), fire remote pushwalls (2 per level), level 35 light switch.
- **Blocking codes:** invisible, block enemies only.
- **Spawn triggers/targets** (guard/SS/officer × 2 channels): crossing a trigger
  warps an active enemy onto every matching target; one-shot.
- **End-level trigger** — floor object that exits.
- **Secrets** count only when crossing a secret / super-secret trigger, not on push.
- **Hurting walls:** animated *fireplace* and *hellwall* textures damage on contact.
- **Automatic doors** open as the player approaches.
- Per-level weapon loadouts on secret levels (eod4sdl `SetLevelWeapons`).

## Roadmap

1. **Foundation** — done: repo, staging, analysis tools, docs.
2. **Maps load** — done: `Scripts/AReyeP/Games.zs` registers SR1/SR2/EOD
   (Spear rules, per-family tables, map numbers 2000/3000/4000 + slot),
   `tools/args.sh` loads the staged files, `tools/gendefs.py` generates
   `GraphicMaps/{SR,EOD}.txt` + `AnimDefs.AReyeP.txt`. Every wall/door code of
   all 84 maps resolves to drawn art (`tools/reportall.sh`).
3. **SR objects** — done (`Scripts/AReyeP/SRActors.zs`, values from MCS's code:
   GetBonus at image 0x12422, TakeRandomDamage, respawn loadout, lightning,
   per-level ambience). Suicide clone: arm/beep/defuse and a barrel-sized blast
   (as carried into eod4sdl). Nothing drops secondary ammo (eod4sdl KillActor).
   Boss ghosts 1-6 are Hans, Gretel, Schabbs, Fettgesicht, Wilhelm, Trans (checked
   against their art), matching the pedestal order.
4. **SR audio, HUD & front end** — done: `tools/assets.py` → `run/AReyeP-data.pk3`
   (60 digitized + 81 AdLib sounds, 28 songs, VGAGRAPH, status bar, MAPINFO with
   songs[]/par/secret exits). SR ends with Spear's own ending (its VGAGRAPH
   carries Spear's end text), so the TC's SoDFinale stays.
5. **Hit points** — done: MCS's starthitpoints tables from both SPEAR.EXEs
   (SR image 0x3AB66, 24 per skill; EoD DS:0x1D04, 16 per skill), applied
   through `AReyePExtension.SetupEnemy` (`AReyePGame.SkillHealth`).
6. **EoD** — done:
   - map plane: 232 walls, door pages 224+, row-0 FlexDesign floors/ceilings,
     its own palette (34 entries differ from Spear's; read from SPEAR.EXE).
   - objects: 133 generated statics (`tools/geneodactors.py`, animated ones
     loop), items, artefacts, triggers, spawn triggers, blocking codes (monster
     -blocking tile edges), teleports, drums.
   - systems (`EoDSwitches.zs`): switches, fire-shooting walls, remote
     pushwalls, light switch, automatic doors; burning walls + well of health.
   - enemies (`EoDEnemies.zs`): flames, Frosty, toilet clone, Ultra Clone,
     Robot, Heinrich, rocket turret; stock bosses voiced with EoD samples.
   - weapons: rifle, launcher, the Spear (thrown, Hell on Earth only).
   - levels (`EoDLevels.zs`): secret-level loadouts, Otto's pistol start,
     "123 you're dead" survival rules, Heinrich's Spear → Hell on Earth → the
     hell Grau ends the game; story texts before levels and the ending
     (`EoDMenus.zs`, VGAGRAPH articles read with the TC's help reader).
   - assets: HUD, title, credits, endings, 39 songs (songs[] DS:0x10EA,
     STARTMUSIC 315), 65 digitized (Spear order) + 80 AdLib sounds, par times
     (DS:0x0A08), progression from eod4sdl's level flags checked against the
     maps' secret elevators.
6b. **Checked against EoD's SPEAR.EXE** (2026-10-26; image offsets, DS = 0x3ddc0).
   Everything eod4sdl had supplied was re-read from MCS's code:
   - DigiMap DS:0xCE: (sound, digi) pairs ordered by digi; it confirms the
     sample names (sound 38 rlaunch, 54 gatling, 57 mk4, 103 turretfire...).
   - statetype records DS:0x1db4-0x3154 (16 bytes: rot, shape, tics, think,
     action, next); actions run as a state *ends*.
   - ScanInfoPlane 0xe6b2 (switch at cs:0x7c2): SpawnBoss(x, y, which) 0x1ad63
     sets class/state/hp per which (5 ghost flame, 6 Frosty, 7 Angel, 8 Trans,
     9 Uber, 10 Wilhelm, 11 Death Knight, 12 Ultra Clone, 13 Heinrich,
     14 Robot, 15 spectre flame); turret 0x1a964 (384 hp outright).
   - FirstSighting 0x156a6 (speed, sight sound), KillActor 0x14bcd (points,
     drops, death state), A_DeathScream 0x1a46f, T_Shoot 0x1b6bc (fire sound
     by class), rocket 0x1a9f1, T_Projectile 0x19a34, blast 0x150b3,
     MoveObj contact damage 0x14af8, enemy pickups 0x1b8d0.
   - level setup 0x105df (arsenals), secret exits/returns 0x1099a (match
     MAPINFO), Greed 0x12502, survival 0x125a2, door sounds 0x18a41.
   - weather: row 0 cells 4-7 are a sky mode before/after a teleport (0 ceiling,
     1 sky, 2+ sky and snow; level setup 0x10d51, DrawSnow 0x5186 is the same
     code as Wolf4SDL's). Differing pairs make it come and go (flake count ramps
     to 300 and back after 30 s spells, 0x1244d). MCS snows over the whole
     level; `EoDWeather.zs` only over areas (door-bounded) whose walls are
     mostly the snowy ones (64, 66-68). Always on (no option). Snowy: Estate Entry, The old Stalag, Frosty; Entryway, The Mines,
     Powder Keg after their teleport. Sky levels show MCS's star sky in place of
     the ceiling, under eod4sdl's drifting clouds.
   SR's SPEAR.EXE (DS = 0x391a0) shares most of it: FirstSighting 0x11830,
   KillActor 0x10f00, clone chase 0x152df, enemy pickups 0x15708.
   Shared MCS rules live in `MCSRules.zs`: enemies pick up health (and steal
   treasure in Greed), landmines and the Artefact of Death kill them (the
   artefact 4-5 a level), MCS's drum/clone blast, SR's first-map full clips.
   Left as is: contact damage of flames/Frosty is 1 a frame in MCS's code
   (2 a game tic here, i.e. 70 fps); unused ghost flame dies plainly.
7. **Front end** — done: game picker with SR, SR New Maps and EoD; MCS's grey
   menus over the rock backdrop, EoD's own menu art, Read This!, MCS's intro
   screens; packaging as the TC IWAD + `AReyeP.pk3` + the player's own data.

## Wolfendoom engine check

`WOLFDOOM.WFD` is an unpacked DOS EXE with Borland procedure and data symbols.
Offsets below are in the loaded image (file offset minus `0x2a00`). Compared
its tables and selected routines with [id Software's Wolf3D source](https://github.com/id-Software/wolf3d/tree/master/WOLFSRC)
and the TC's Wolf3D actors. No Wolfendoom gameplay differences were found:

| Area | EXE evidence | Result |
|---|---|---|
| Enemy health | `starthitpoints` `0x3b4c2` (88 words) | Byte-for-byte stock, all four skills and 22 enemy slots. Hitler's human form uses the stock 500/700/800/900 HP (`A_HitlerMorph`; `SpawnHitler` at `0x14cb5` uses the table for the mech). |
| Enemy movement and reactions | `SpawnStand` `0x13ed8`, `SpawnPatrol` `0x14139`, `FirstSighting` `0x11b26`, `SightPlayer` `0x11d74` | Stock patrol speeds (512, dog 1500), chase multipliers and class-dependent sight delays. |
| Enemy attacks | `T_Shoot` `0x154c6`, `T_Bite` `0x1567e`, `T_Projectile` `0x13d1c` | Stock distance-based hit chances and damage, including the dog bite and boss projectiles. |
| Kills and drops | `KillActor` `0x1144b`, `DamageActor` `0x116fc` | Stock points, clip/weapon/key drops, pain reactions, and double damage before an enemy enters attack mode. |
| Player and weapons | `attackinfo` `0x3b2a4` (224 bytes), `KnifeAttack` `0x12b65`, `GunAttack` `0x12be2`, `TakeDamage` `0x121b2`, `NewGame` `0x4bff` | Stock four-weapon firing sequence and damage; Baby difficulty quarters player damage. New game starts with 100 health, 8 rounds, pistol, 3 lives. |
| Pickups and lives | `GetBonus` `0x123cc`, `GiveWeapon` `0x1233d`, `GiveAmmo` `0x12382`, `GiveExtraMan` `0x1226c`, `GivePoints` `0x122a3` | Stock: clips 8/dropped clips 4, weapons 6, ammo cap 99; health 25/10/4/1, full heal plus 25 ammo and a life; treasure 100/500/1000/5000, extra life every 40,000 points, life cap 9. |
| Cheats and debug | `CheckKeys` `0xd6bf` | Stock M-L-I and B-A-T combinations, Backspace+Left Shift+Alt debug enable, and `goobers`; the TC's stock cheat handling remains enabled for WFD. |

The gameplay procedure names in the EXE's symbol table all occur in the
released Wolf3D source; none identifies a new MCS subsystem. This is a
targeted comparison of the named tables and routines, not a byte-level audit
of every EXE function. WFD therefore uses the TC's existing Wolf3D rules;
no WFD-specific gameplay overrides are needed.

## Dev setup

- Engine: the TC targets ZScript 5.0 → **UZDoom 5.x** (AUR `uzdoom-bin`).
- `python3 tools/stage.py run --source <folder with the zips>` — stage data into `run/` (ignored).
- `python3 tools/gendefs.py run` — regenerate VSWAP name tables/canvases.
- `python3 tools/assets.py run` — build `run/AReyeP-data.pk3` (ignored): SR
  VGAGRAPH pictures + HUD texture names, SR music (IMF wrapped as `ADLIB\1`),
  and the generated SR1/SR2 MAPINFO (names, MCS's songs[] table, secret exits
  2→18, 9→21, 12→19, 15→22 and their returns, Spear level 17 → Afterlife 20).
  Loaded with `-file` (`tools/args.sh`). Don't rebuild it (or the packs) while a game is running.
- `python3 tools/build.py [SUFFIX]` — pack the TC (`../Wolf3D-TC-3.0` or
  `$WOLF3D_TC`) into `run/Wolf3D-TC.ipk3` and this repo into `run/AReyeP.pk3`
  (tests use the `-test` suffix, which `headless.sh`/`reportall.sh` build).
- `tools/headless.sh SECS args…` — run the engine offscreen (SDL `offscreen`
  driver + OpenGL); prints the filtered log. Useful args:
  `+areyep_startmap GAMEMAPS.SR1:Black_Forest +map Level` (start a parsed map
  directly; `_` for spaces), `+areyep_report 1` (log unmapped codes, undrawn
  wall textures and spawned actors), `+areyep_probe 1` (state once a second).
  Console `wait` doesn't work in this mode, so automated checks live in ZScript.
- `tools/reportall.sh SR1` — report every map of a mapset → `run/report-SR1.txt`
  (codes, art, health per class, missing sprites, door slabs, player loadout).
- `+areyep_switchtest 1` throws every EoD switch; `+areyep_summon "A,B"` lines
  classes up in front of the player (`+areyep_summonlive 1`: let them act).
- `+areyep_watch "A,B"` logs those classes (frame, health, distance) once a
  second plus every damage event; `+areyep_wake 1` alerts every enemy,
  `+areyep_hurt N` hits the watched classes for N, `+areyep_remove "A,B"`
  deletes those classes three seconds in. Add `+areyep_report 1` on maps with
  story screens (they pause the game otherwise), `+god` to watch longer.
- `tools/shot.sh OUT.png SECS args…` — screenshot the test build in a gamescope
  window (kills the window afterwards; gamescope ignores SIGTERM).
- Headless runs end by SIGTERM; UZDoom sometimes aborts in `exit()` then, which
  shows up as a "uzdoom crashed" notification — harmless.
- `python3 tools/codes.py LABEL MAPHEAD GAMEMAPS [first last]` — code histogram.
- `python3 tools/sheet.py VSWAP walls|sprites out.png [--start --count]` — contact sheet.
- Seen once: an engine segfault on the demo map (not reproducible in 3 reruns).
