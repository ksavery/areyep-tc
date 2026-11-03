AReyeP TC - Spear Resurrection, End of Destiny and Wolfendoom on the Wolf3D TC
===============================================================================

AReyeP and MCS's Spear Resurrection (the 2001 maps and the 2011 SDL new
mapset), Spear: End of Destiny v1.12 and Wolfendoom (2001), running as a mod on AFADoomer's
Wolf3D TC 3.0 in UZDoom. Pick the game from the game menu at startup.

Everything is in this folder, including UZDoom for Windows. Nothing to
install or build.

Windows
  1. Extract the whole zip first (right-click > Extract All). It won't run
     from inside the zip. Extract it somewhere of your own, such as C:\Games
     or another drive, rather than C:\Program Files.
  2. Double-click play.bat.
  If Windows SmartScreen says it "protected your PC", click "More info" and
  then "Run anyway" (it does that for programs downloaded from the internet).

Linux
  Install UZDoom 5.x (your distro's package, or the AppImage from
  https://github.com/UZDoom/UZDoom/releases), then run ./play.sh
  (it uses uzdoom from PATH, or UZDOOM=/path/to/uzdoom ./play.sh).
  The uzdoom folder here is the Windows build; Linux doesn't use it.

If it won't start
  play.bat tries again with OpenGL by itself if UZDoom stops while starting
  up (on basic laptop graphics, Vulkan is the usual reason), and keeps using
  it. If the game still won't start, or runs slowly, use play-safe.bat:
  OpenGL, no dynamic lights and no distance shading. Those stay set when
  play.bat is used again, and can be turned back on in the options.
  To report a problem, send play.log (and play-vulkan.log, if there is one)
  with your version of Windows.

Settings (areyep.ini) and play.log are kept next to the game. Where Windows
won't let anything be written there, they go in %LOCALAPPDATA%\AReyeP-TC
instead (paste that into the File Explorer address bar to open it).

What's in the folder
  play.bat, play.sh  start the game
  play-safe.bat      start it with OpenGL and the heavier effects off
  uzdoom\            UZDoom 5.0.3 for Windows, unchanged from its official
                     release (licences in uzdoom\licenses.zip; source at
                     https://github.com/UZDoom/UZDoom)
  Wolf3D-TC.ipk3     the Wolf3D TC (with the game-extension hooks from
                     AFADoomer/Wolf3D-TC-3.0#82), loaded as the IWAD
  AReyeP.pk3         the AReyeP mod, loaded on top of the TC
  AReyeP-data.pk3    the games' music, pictures and texts, converted from
                     AReyeP's original files
  VSWAP.*, GAMEMAPS.*, MAPHEAD.*
                     AReyeP's original game files (art and maps), renamed
                     per game: .SR (Spear Resurrection art), .SR1 (2001 maps),
                     .SR2 (2011 maps), .EOD (End of Destiny), .WFD (Wolfendoom)
  LICENSE.txt        the mod's licence (GPL-3.0)

Source: https://github.com/ksavery/areyep-tc (mod)
        https://github.com/ksavery/Wolf3D-TC-3.0, branch areyep-dev (TC)

Credits
  Spear Resurrection and Spear: End of Destiny - AReyeP (Steve Walley) and
  MCS Amsterdam, with BrotherTank; https://www.areyep.com/
  Wolfendoom - AReyeP, with MCS Amsterdam
  Spear Resurrection SDL - Andy Nonymous (SDL code), Ack (two new levels)
  EOD4SDL recreation (behaviour reference) - Kyle Albert
  Wolf3D TC 3.0 - AFADoomer; see Credits-Wolf3D-TC.txt
  UZDoom - the UZDoom team; https://github.com/UZDoom/UZDoom
  Wolfenstein 3D / Spear of Destiny - id Software, FormGen
