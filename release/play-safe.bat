@echo off
rem AReyeP TC in safe mode, for computers play.bat doesn't run well on: OpenGL
rem in place of Vulkan, no dynamic lights and no distance shading. These are
rem saved like any other setting, so they stay that way when play.bat is used
rem again; they can all be turned back on in the options.
call "%~dp0play.bat" +vid_preferbackend 0 +g_dynamiclights 0 +areyep_shadestrength 0 %*
