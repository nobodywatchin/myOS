#!/usr/bin/env bash
# Attach autoblock filter to user remotes and mask system-installed apps.

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
    sub(/.*name:[[:space:]]*/,"")
    gsub(/["'"'"']/,"")
    print
    got=1
    exit
  }
' "$CFG" 2>/dev/null || echo flathub)

# parse user remote url
USER_URL=$(awk '
  BEGIN{in_user=0}
  /^- /{in_user=0}
  /^[[:space:]]*scope:[[:space:]]*user/{in_user=1}
  in_user && /^[[:space:]]*url:/ {
    sub(/.*url:[[:space:]]*/,"")
    gsub(/["'"'"']/,"")
    print
    exit
  }
' "$CFG" 2>/dev/null || echo https://dl.flathub.org/repo/flathub.flatpakrepo)

echo "Using user remote: $USER_REMOTE ($USER_URL)"

# collect app IDs from filter (deny lines)
mapfile -t APPIDS < <(awk '/^deny[[:space:]]+app\//{sub(/^deny[[:space:]]+app\//,""); sub(/\/\*$/,""); print}' "$FILTER")

# iterate real homedirs
for home in /home/*; do
  [[ -d "$home" ]] || continue
  u=$(basename "$home")
  echo "Applying to user: $u"

  su -l "$u" -s /bin/bash -c "
    set -e
    # ensure user remote exists
    flatpak --user remote-add --if-not-exists --from \"$USER_URL\" \"$USER_REMOTE\" || true
    # attach filter and refresh
    flatpak --user remote-modify --filter=\"$FILTER\" \"$USER_REMOTE\" || true
    flatpak --user update --appstream || true
    # mask explicit installs
    for id in ${APPIDS[@]}; do
      flatpak mask --user \"\$id\" >/dev/null 2>&1 || true
    done
  "
done
