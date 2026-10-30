#!/bin/bash
# Start the AReyeP games (the live packs in run/). Launchers (Faugus, desktop
# entries) point here; game-hdr-gamescope or similar wraps it in gamescope.
#   tools/play.sh [uzdoom args...]
tools=$(dirname "$(readlink -f "$0")")
cd "$tools/../run" || exit 1
. "$tools/args.sh"
areyep_args ""
# Settings of their own: the TC IWAD's config section ("Wolf3D") would
# otherwise be shared with the stock TC
config=${XDG_CONFIG_HOME:-$HOME/.config}/uzdoom/areyep.ini
exec uzdoom "${args[@]}" -config "$config" +logfile play.log "$@"
