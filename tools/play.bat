@echo off
rem Start the AReyeP games on Windows (the live packs in run\): the TC as the
rem IWAD, the mod and the game data on top. Keep the file list in step with
rem tools/args.sh. Set UZDOOM to uzdoom.exe's full path if it isn't on PATH.
rem   tools\play.bat [uzdoom args...]
setlocal
cd /d "%~dp0..\run" || exit /b 1
if not defined UZDOOM set "UZDOOM=uzdoom"

rem Settings of their own, kept in the game folder (run\areyep.ini)
"%UZDOOM%" -iwad Wolf3D-TC.ipk3 -file AReyeP.pk3 AReyeP-data.pk3 ^
	VSWAP.SR GAMEMAPS.SR1 MAPHEAD.SR1 GAMEMAPS.SR2 MAPHEAD.SR2 ^
	VSWAP.EOD GAMEMAPS.EOD MAPHEAD.EOD ^
	-config areyep.ini +logfile play.log %*
