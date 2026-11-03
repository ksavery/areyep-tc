#!/bin/bash
# AReyeP TC: Spear Resurrection and End of Destiny on the Wolf3D TC.
# Uses uzdoom from PATH (the bundled uzdoom folder is the Windows build), or $UZDOOM.
cd "$(dirname "$(readlink -f "$0")")" || exit 1
exec "${UZDOOM:-uzdoom}" -iwad Wolf3D-TC.ipk3 -file AReyeP.pk3 AReyeP-data.pk3 \
	VSWAP.SR GAMEMAPS.SR1 MAPHEAD.SR1 GAMEMAPS.SR2 MAPHEAD.SR2 \
	VSWAP.EOD GAMEMAPS.EOD MAPHEAD.EOD \
	VSWAP.WFD GAMEMAPS.WFD MAPHEAD.WFD -config areyep.ini "$@"
