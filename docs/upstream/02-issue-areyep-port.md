# Issue AFADoomer/Wolf3D-TC-3.0#81 (posted)

**Title:** AReyeP & MCS's Spear Resurrection and End of Destiny, ported onto the TC — proposal for a small game-extension hook

**Body:**

Hi AFADoomer,

I've ported AReyeP and MCS's Spear mods — **Spear Resurrection** (the 2001
maps and the 2011 SDL mapset) and **Spear: End of Destiny** (v1.12) — onto
your Wolf3D TC 3.0, running on UZDoom. All three are playable start to
finish.

The TC does nearly all of the work: the map builder, doors and pushwalls,
the actors, menus, status bar, intermission and VSWAP/VGAGRAPH loading are
yours, unchanged. On top of it I added the mods' content (the TileCodes
and GraphicMaps tables for both games, their actors, items and level
scripts) and MCS's game rules, read out of the original SPEAR.EXEs (enemy
hit points and speeds, scores, drums and breakable columns, cheat keys,
EoD's switches, fire walls, weather and so on). Your existing credit to
AReyeP for the broken-column sprites and floor textures is how I found
there was already a connection.

I'd like this to stay **a mod of your TC** rather than drift off as a
fork, so the TC keeps the credit for the engine side and both projects keep
benefiting from each other. To be clear about intent: the TC stays yours to
run. Anything I'd add to it would be general extension points, offered as
PRs for you to accept, shape or turn down; the AReyeP games themselves would
only hook in through what the TC provides, and live entirely in their own
mod. Today it is a fork: about 3,900 lines of new
script live in their own files, but I also had to put 29 small edits into
your files — mostly one-line hooks of the form "if this is an AReyeP game,
do X". The general bug fixes among them are in #80.

**Proposal:** a small "game extension" class that the TC asks at the points
where a mod game differs, which does nothing by default. A mod would
register a subclass (e.g. from its MAPINFO or an event handler), and the
TC's own Spear / Lost Episodes special cases could move onto the same hooks
over time. The points I needed:

| Where in the TC | Hook |
|---|---|
| `GameHandler.GetMusic` | map a TC song name (title, menu, intermission, ending) to the game's own |
| menus, Get Psyched, status bar border, intermission | draw the game's backdrop; window fill and bevel colours; intermission background |
| menu texture lookups | a game's own variant of a menu graphic |
| `MapHandler` wall builder | actor codes that sit in wall tiles and keep them solid |
| `MapHandler` / `ReplacementHandler` flats | floor/ceiling colours or textures per map (and sky) |
| `ClassicStatusBar` | draw a game's own status bar (or select its bar class) |
| `ClassicStats` | demo-ending rule; which finale menu to open |
| `SpearofDestiny` | which level ends when the Spear is taken |
| `ClassicBase.BeginPlay` | per-game hit points, score and chase speed for stock enemies |
| `KeyHandler` | a game's own cheat keys in place of Wolf3D's |
| `DoorHandler` | door sound sequences; doors that open themselves |

With those in place, the AReyeP port would ship as a PWAD loaded on top of
an unmodified TC (`-iwad <TC> -file AReyeP.pk3 AReyeP-data.pk3`; the game
data itself is staged from the user's own copies of AReyeP's downloads).
I'm happy to write the extension class and the TC-side calls as a PR, in
your style, if you're open to the idea — or to shape it however you'd
prefer. The extension points would be general (useful to any game or mod
built on the TC, including the TC's own Spear and Lost Episodes cases); the
AReyeP-specific behaviour stays in the mod.

The port is at https://github.com/ksavery/areyep-tc (private for now; I
can give you access).
