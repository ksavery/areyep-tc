# Pull request AFADoomer/Wolf3D-TC-3.0#80 (posted)

Branch: `upstream-fixes` (one commit on top of 5c70b65, the current master)

**Title:** Fixes for maps loaded from Wolf3D GAMEMAPS files

**Body:**

Hi AFADoomer,

While building on the TC I ran into a few bugs that affect any map the TC
parses from GAMEMAPS/MAPHEAD files. Those maps all run inside the shared
`Level` map, so code that reads the engine level's name, number or par time
gets `Level`'s values instead of the map's own. These are small, general
fixes, independent of anything of mine:

- **Intermission stats** — `MapStatsHandler` stores a parsed map's stats
  under the map's own name, but `ClassicStats` looked them up as `Level`, so
  the screen stopped before counting: ratios stuck at 0% and no count-up.
- **Time bonus** — par came from `Level` (which has none), so the bonus was
  always 0. It now comes from the parsed map's MAPINFO entry.
- **Spear of Destiny** — the level-18 check read `Level`'s `levelnum` (-1),
  so picking up the Spear never ended the level on a parsed map. It now uses
  the parsed map's level number.
- **Get Psyched hang** — the fade and close steps waited for an exact
  `gametic`, which can be stepped past while a level loads, leaving the
  screen up for good. They now trigger at or after that tic.
- **Weapon drops** — `A_DeathDrop` now counts weapons derived from the drop
  class, so a player who already has a subclassed version of the weapon (a
  mod's pickup variant of the pistol, for example) isn't given another on
  every kill.

5 files, +29/−6. Compiles and runs on UZDoom 5.0.3; the intermission, time
bonus and Spear fixes were tested on parsed maps.

Thanks for the TC — more on what I used it for in #81.
