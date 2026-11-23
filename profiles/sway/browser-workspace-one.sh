#!/usr/bin/env bash
# Open LibreWolf on workspace 1 or focus its existing window, without duplicates.
set -euo pipefail
browser=${1:?Pass the LibreWolf executable path}
swaymsg_bin=${2:-swaymsg}
lock_dir=${XDG_RUNTIME_DIR:-/tmp}
exec 9>"$lock_dir/librewolf-workspace-one-$UID.lock"
flock -w 30 9 || exit 0

find_browser() {
  "$swaymsg_bin" -t get_tree | jq -r '
    [.. | objects
      | select(([(.app_id // ""), (.window_properties.class // "")]
          | any(. | ascii_downcase | contains("librewolf"))))
      | .id][0] // empty'
}
"$swaymsg_bin" 'workspace number 1' >/dev/null
id=$(find_browser)
if [[ -n "$id" ]]; then
  "$swaymsg_bin" "[con_id=$id] move container to workspace number 1; [con_id=$id] focus" >/dev/null
  exit 0
fi
"$swaymsg_bin" exec "$browser" >/dev/null
# A launch can take a while, especially on the browser's first run. Hold the
# lock until its window is visible so repeated Super+1 does not spawn duplicates.
for _ in $(seq 1 200); do
  id=$(find_browser)
  if [[ -n "$id" ]]; then
    "$swaymsg_bin" "[con_id=$id] focus" >/dev/null
    exit 0
  fi
  sleep 0.2
done
echo 'LibreWolf did not open a window within 40 seconds.' >&2
exit 1
