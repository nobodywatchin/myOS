#!/usr/bin/env bash
# apply-flatpak-blocklist.sh
set -euo pipefail

CFG="/usr/share/bluebuild/default-flatpaks/configuration.yaml"
FILTER=$(ls /etc/flatpak/filters/*.autoblock.filter 2>/dev/null | head -n1 || true)

if [[ -z "$FILTER" ]]; then
  echo "No autoblock filter found; skipping"
  exit 0
fi

# parse user remote name
USER_REMOTE=$(awk '
  BEGIN{in_user=0; got=0}
  /^- /{in_user=0}
  /^[[:space:]]*scope:[[:space:]]*user/{in_user=1}
  in_user && /^[[:space:]]*name:/ && !got {
    sub(/.*name:[[:space:]]*/,""); gsub(/["'\''"]/,""); print; got=1; exit
  }
' "$CFG" 2>/dev/null || echo flathub)

# parse user remote url
USER_URL=$(awk '
  BEGIN{in_user=0}
  /^- /{in_user=0}
  /^[[:space:]]*scope:[[:space:]]*user/{in_user=1}
  in_user && /^[[:space:]]*url:/ {
    sub(/.*url:[[:space:]]*/,""); gsub(/["'\''"]/,""); print; exit
  }
' "$CFG" 2>/dev/null || echo https://dl.flathub.org/repo/flathub.flatpakrepo)

echo "Using user remote: $USER_REMOTE ($USER_URL)"

# iterate real homedirs
for home in /home/*; do
  [[ -d "$home" ]] || continue
  u=$(basename "$home")
  echo "Applying to user: $u"

  su -l "$u" -s /bin/bash -c "
    set -e
    # ensure user remote exists (NOTE: NAME then URL)
    flatpak --user remote-add --if-not-exists --from \"$USER_REMOTE\" \"$USER_URL\" || true
    # attach filter and refresh appstream
    flatpak --user remote-modify --filter=\"$FILTER\" \"$USER_REMOTE\" || true
    flatpak --user update --appstream || true
    # derive appids from the filter and mask them (hard-block explicit installs)
    awk '/^deny[[:space:]]+app\\//{sub(/^deny[[:space:]]+app\\//,\"\"); sub(/\\/\\*$/,\"\"); print}' \"$FILTER\" \
      | while read -r id; do
          [ -n \"\$id\" ] && flatpak mask --user \"\$id\" >/dev/null 2>&1 || true
        done
  "
done
