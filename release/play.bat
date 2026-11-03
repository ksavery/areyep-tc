@echo off
rem AReyeP TC: Spear Resurrection, End of Destiny and Wolfendoom on the Wolf3D TC.
rem Double-click to play. Uses the UZDoom in the uzdoom folder next to this file;
rem set UZDOOM to another uzdoom.exe to use that one instead.
rem
rem Settings (areyep.ini) and the log (play.log) are kept next to the game, or in
rem %LOCALAPPDATA%\AReyeP-TC when Windows won't let anything be written here
rem (Program Files, a folder OneDrive keeps online). If UZDoom stops before it has
rem finished starting up, it's tried again with OpenGL, which is then kept
rem (delete use-opengl.txt beside the log to go back).
setlocal EnableDelayedExpansion

rem Wait minimized behind the game, rather than as an open window
if not defined AREYEP_LAUNCHED (
	set "AREYEP_LAUNCHED=1"
	start "AReyeP TC" /min cmd /c ""%~f0" %*"
	exit /b
)

cd /d "%~dp0"
if not defined UZDOOM if exist "%~dp0uzdoom\uzdoom.exe" set "UZDOOM=%~dp0uzdoom\uzdoom.exe"
if not defined UZDOOM set "UZDOOM=uzdoom"

set "DATA=%~dp0"
copy /y nul "%~dp0.writetest" >nul 2>&1
if exist "%~dp0.writetest" (
	del "%~dp0.writetest" >nul 2>&1
) else (
	set "DATA=%LOCALAPPDATA%\AReyeP-TC\"
	if not exist "!DATA!" mkdir "!DATA!"
	if not exist "!DATA!areyep.ini" if exist "%~dp0areyep.ini" copy "%~dp0areyep.ini" "!DATA!" >nul
)

set FILES=-iwad Wolf3D-TC.ipk3 -file AReyeP.pk3 AReyeP-data.pk3 VSWAP.SR GAMEMAPS.SR1 MAPHEAD.SR1 GAMEMAPS.SR2 MAPHEAD.SR2 VSWAP.EOD GAMEMAPS.EOD MAPHEAD.EOD VSWAP.WFD GAMEMAPS.WFD MAPHEAD.WFD
set "RENDER="
if exist "%DATA%use-opengl.txt" set "RENDER=+vid_preferbackend 0"

"%UZDOOM%" %FILES% -config "%DATA%areyep.ini" +logfile "%DATA%play.log" %RENDER% %*
set "CODE=%ERRORLEVEL%"

rem Quit normally, already on OpenGL, or it got as far as the game: done
if "%CODE%"=="0" exit /b 0
if defined RENDER exit /b %CODE%
findstr /c:"Init complete." "%DATA%play.log" >nul 2>&1 && exit /b %CODE%

rem It stopped while starting up, most often Vulkan on basic graphics: OpenGL
rem from now on, keeping the first try's log
copy /y "%DATA%play.log" "%DATA%play-vulkan.log" >nul 2>&1
echo UZDoom stopped while starting up (code %CODE%), so OpenGL is used instead.> "%DATA%use-opengl.txt"
"%UZDOOM%" %FILES% -config "%DATA%areyep.ini" +logfile "%DATA%play.log" +vid_preferbackend 0 %*
exit /b %ERRORLEVEL%
