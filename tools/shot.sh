#!/bin/bash
# Screenshot the test build in a gamescope window: tools/shot.sh OUT.png SECS [uzdoom args...]
# Runs the test packs (never the live ones), captures the window with grim,
# then kills the whole process group (gamescope ignores SIGTERM).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
out=$1 secs=$2
shift 2
cd "$root/run" || exit 1
. "$root/tools/args.sh"
areyep_args -test
setsid gamescope -W 1280 -H 800 -w 1280 -h 800 -- uzdoom "${args[@]}" -config uzdoom-test.ini -nosound "$@" >/dev/null 2>&1 &
pid=$!
sleep "$secs"
# The newest gamescope window's geometry
geom=$(hyprctl -j clients | python3 -I -c '
import json, sys
c = [w for w in json.load(sys.stdin) if w["class"].lower().startswith("gamescope")]
if c:
    w = max(c, key=lambda w: w.get("focusHistoryID", 0) * -1)
    print("%d,%d %dx%d" % (w["at"][0], w["at"][1], w["size"][0], w["size"][1]))
')
grim ${geom:+-g "$geom"} "$out"
kill -9 -- -"$pid" 2>/dev/null
echo "$out ${geom:-full screen}"
