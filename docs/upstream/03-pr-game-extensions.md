# Pull request AFADoomer/Wolf3D-TC-3.0#82 (posted; closed and reopened 2026-10-28)

Branch: `game-extensions` on ksavery/Wolf3D-TC-3.0 (825f380 + 3dbc1e6); #80 was merged 2026-10-27

**Title:** Game extensions: hooks for mods that add their own games

**Body:**

Hi AFADoomer,

This is the extension layer I proposed in #81. It lets a mod add its own
games to the TC (GAMEMAPS/MAPHEAD/VSWAP files with their own extension) and
change how the TC presents and plays them, without editing TC code. With it,
my AReyeP port now loads as a PWAD on top of this branch with no other changes
to the TC.

There's also a small separate commit: the startup notice drew its
background in the text's virtual size, so on screens of a different shape
it covered only part of the screen; it now stretches over the whole screen.

**How it works**

- `Scripts/Extensions/GameExtension.zs` adds `GameExtension`, a class a mod
  subclasses. `GameExtensionHandler` (first in MAPINFO's EventHandlers)
  creates one of each subclass at startup.
- At each hook the TC asks the extension that claims the game being played
  (`Handles(ext)`), or before any game is picked, the one that says
  `IsDefault()`. Every hook does nothing by default, and with no extension
  loaded the TC behaves exactly as before. I compared screenshots of
  master and this branch on the TC's own maps and saw no difference.
- The game picked in the game menu is kept in a new `g_modgame` CVar.

**Hooks**

| Area | Hooks |
|---|---|
| Games | `ListGames`, `DataSet` (several games sharing one VSWAP/GraphicMaps/TileCodes set), `Title`, `GameType`, `MapNumber` |
| Map building | `PrepareMap`, `WallActor` (actor codes that keep their wall), `LevelFlats` (floor/ceiling colours, textures, sky), `StartingMap` |
| Doors | `AllowDoorUse`, `DoorSound`, `PushwallMoves` |
| Actors | `SetupEnemy` (hit points, score, speed), `PickupMessage`, `SpearEndsLevel` |
| Screens | `Music`, `DrawBackdrop`, `WindowColors`, `MenuBox`, `ReadThis`, `DisabledColor`, `MenuTexture`, `FadeColor`, `IntermissionColor`, `FinaleMenu`, `Episode`, `SkipIntro`, `IntroGraphic`, `DrawIntroScreen` |
| Status bar | `DrawStatusBar`, `DrawOverlay`, `ProcessNotify`, `ProcessMidPrint` |
| Input | `InputProcess`, `StockCheats` |

**Smaller data-driven additions** the port needed. Each is opt-in, so
existing data is unaffected:

- TileCodes: an optional `Frame` per door tile (its own door-frame textures).
- GraphicMaps: optional `SpritePrefix` (data sets that share sprite names
  get their own) and `NoShadowMask` (for sprites with painted shadows).
- `GraphicsHandler.Activate(ext)`: redraws one data set's VSWAP, for games
  that share canvas names.
- `ActorMap.GetActor` can look actors up by game name before the gametype tables.
- A parsed map's own `gametype` is used when it has one.
- `ParsedMap.extdata`, where an extension can keep its per-map data.
- Generic fallbacks: `ClassicStatusBar.DrawMugShot` takes a face prefix and
  accuracy; `OldHelpMenu.graphicprefix`; `ClassicBase` gets an optional
  `goal` spot for chase/dodge movement.
- Picking a game resets the main menu's selection to its first item.

22 files, mostly one-line call sites in the form "ask the extension, else
do what the TC did". It compiles and runs on UZDoom 5.0.3, both alone and
with the AReyeP mod loaded. With the mod, I compared map-by-map load reports
of all 84 SR/EoD maps before and after moving it onto these hooks.

I'm happy to rename things, cut hooks you'd rather not have, or reshape any
of it to fit how you'd like the TC to grow. The mod using it is at
https://github.com/ksavery/areyep-tc (`AReyePExtension` is its hook);
I'll get you access as mentioned in #81.
