#!/usr/bin/env bash
# apply-flatpak-blocklist.sh
# Use the existing user remote (e.g., flathub), attach the autoblock filter to it,
# and keep the system remote out of GNOME Software's catalog.

set -euo pipefail

CFG="/usr/share/bluebuild/default-flatpaks/configuration.yaml"
FILTER="$(ls /etc/flatpak/filters/*.autoblock.filter 2>/dev/null | head -n1 || true)"

if [[ -z "$FILTER" ]]; then
  echo "No autoblock filter found in /etc/flatpak/filters/*.autoblock.filter; nothing to apply."
  exit 0
fi

# Parse user remote name from config (fallback: flathub)
USER_REMOTE="$(
  awk 'BEGIN{u=0}
       /^- /{u=0}
       /^[[:space:]]*scope:[[:space:]]*user/{u=1}
       u && /^[[:space:]]*name:/{sub(/.*name:[[:space:]]*/,""); gsub(/["'\''"]/,""); print; exit}' \
  "$CFG" 2>/dev/null || echo flathub
)"

# Parse user remote URL from config (fallback: standard Flathub)
USER_URL="$(
  awk 'BEGIN{u=0}
       /^- /{u=0}
       /^[[:space:]]*scope:[[:space:]]*user/{u=1}
       u && /^[[:space:]]*url:/{sub(/.*url:[[:space:]]*/,""); gsub(/["'\''"]/,""); print; exit}' \
  "$CFG" 2>/dev/null || echo https://dl.flathub.org/repo/flathub.flatpakrepo
)"

echo "Using user remote: $USER_REMOTE"
echo "User remote URL  : $USER_URL"
echo "Filter file      : $FILTER"

# System scope: keep managed system remote out of GS enumeration (idempotent)
flatpak --system remote-modify --no-enumerate org-system 2>/dev/null || true
flatpak --system update --appstream || true

# Apply to each real user
for home in /home/*; do
  [[ -d "$home" ]] || continue
  u="$(basename "$home")"
  echo "Applying for user: $u"

  su -l "$u" -s /bin/bash -c "
    set -e
    # Ensure the user remote exists (NAME then URL)
    flatpak --user remote-add --if-not-exists --from \"$USER_REMOTE\" \"$USER_URL\" || true

    # Attach the filter to the existing user remote and ensure it's enumerated
    flatpak --user remote-modify --filter=\"$FILTER\" --enumerate \"$USER_REMOTE\" || true

    # Refresh AppStream at user scope
    flatpak --user update --appstream || true

    # Clear GNOME Software caches to force a clean rescan
    rm -rf \"\$HOME/.cache/gnome-software\"/* \"\$HOME/.local/state/gnome-software\"/* 2>/dev/null || true
  "
done

# If GNOME Software is running in any session, nudge it to reload data
killall gnome-software 2>/dev/null || true

echo "Done. GNOME Software will enumerate only the filtered user remote: $USER_REMOTE"
