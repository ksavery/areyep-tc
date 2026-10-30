# Engine arguments for the AReyeP games: the TC as the IWAD, the mod and its
# staged data on top. Sourced by the launch scripts; run from run/.
# tools/play.bat has the same list for Windows: keep the two in step.
#   areyep_args SUFFIX   ("" for the live packs, "-test" for test builds)
areyep_args() {
	local suffix=$1
	args=(-iwad "Wolf3D-TC$suffix.ipk3" -file "AReyeP$suffix.pk3" AReyeP-data.pk3
		VSWAP.SR GAMEMAPS.SR1 MAPHEAD.SR1 GAMEMAPS.SR2 MAPHEAD.SR2
		VSWAP.EOD GAMEMAPS.EOD MAPHEAD.EOD
		VSWAP.WFD GAMEMAPS.WFD MAPHEAD.WFD)
}
