#!/bin/bash
# Run the in-game map report (areyep_report) for every map of a staged mapset.
# usage: tools/reportall.sh EXT   e.g. SR1 -> run/report-SR1.txt
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
ext=$1
out="$root/run/report-$ext.txt"
: >"$out"
python3 -I "$root/tools/build.py" -test >/dev/null || exit 1
python3 -I "$root/tools/mapnames.py" "$root/run/MAPHEAD.$ext" "$root/run/GAMEMAPS.$ext" | while IFS= read -r name; do
	NOBUILD=1 "$root/tools/headless.sh" 12 +areyep_report 1 +areyep_startmap "GAMEMAPS.$ext:$name" +map Level \
		| grep -a '^REPORT' >>"$out"
done
echo "$out"
