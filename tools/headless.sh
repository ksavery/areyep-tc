#!/bin/bash
# Build the test packs and run UZDoom offscreen (SDL offscreen driver + OpenGL).
#
# usage: tools/headless.sh SECONDS [uzdoom args...]
#   e.g. tools/headless.sh 15 +areyep_report 1 +areyep_startmap GAMEMAPS.SR1:Black_Forest +map Level
# The engine runs until the timeout; output goes to run/log.txt and the
# filtered log is printed. Set NOBUILD=1 to reuse the existing packs.
# Console "wait" doesn't delay anything here (and in-level "screenshot"
# never fires), so checks are done from ZScript (areyep_report) instead.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
secs=${1:-60}
shift || true

cd "$root/run" || exit 1
# Tests use their own packs so they never rewrite the live ones while someone is playing
[ -n "${NOBUILD:-}" ] || python3 -I "$root/tools/build.py" -test >/dev/null || exit 1
. "$root/tools/args.sh"
areyep_args -test
SDL_VIDEODRIVER=offscreen timeout -k 5 "$secs" stdbuf -o0 -e0 \
	uzdoom "${args[@]}" -nosound -stdout -config "$root/run/uzdoom-test.ini" \
	+vid_preferbackend 0 "$@" </dev/null >log.txt 2>&1
rc=$?
sed 's/\x1b\[[0-9;]*m//g' log.txt | grep -av '[░║═]' | sed -n '/^LoadActors/,$p'
[ $rc -eq 124 ] && echo "(timed out after ${secs}s)"
exit 0
