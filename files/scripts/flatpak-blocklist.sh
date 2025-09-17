#!/usr/bin/env bash
# Generate a Flatpak filter that blocks system-installed app IDs on the user remote.
set -euo pipefail

CFG="${1:-/usr/share/bluebuild/default-flatpaks/configuration.yaml}"
FILTER_DIR="/etc/flatpak/filters"

[[ -f "$CFG" ]] || { echo "config not found: $CFG" >&2; exit 1; }

mkdir -p "$FILTER_DIR"

# 1) Extract the *user* remote name (e.g. 'flathub') from the first 'scope: user' block.
user_remote="$(awk '
  BEGIN{in_user=0; got=0}
  /^- /{in_user=0}                                  # new top-level item
  /^[[:space:]]*scope:[[:space:]]*user[[:space:]]*$/{in_user=1}
  in_user && /^[[:space:]]*name:[[:space:]]*/ && !got {
    line=$0; sub(/.*name:[[:space:]]*/,"",line); gsub(/["'\'']/, "", line);
    print line; got=1; exit
  }
' "$CFG")"

user_remote="${user_remote:-flathub}"               # fallback if not present

# 2) Collect the system 'install:' list from the first 'scope: system' block.
mapfile -t SYSTEM_APPIDS < <(awk '
  BEGIN{in_system=0; capture=0}
  /^- /{ if(capture){ exit } capture=0; in_system=0 } # end system block once a new top item starts
  /^[[:space:]]*scope:[[:space:]]*system[[:space:]]*$/{in_system=1}
  in_system && /^[[:space:]]*install:[[:space:]]*$/{capture=1; next}
  capture && /^[[:space:]]*-[[:space:]]/ {
    line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line); gsub(/["'\'']/, "", line);
    print line
  }
' "$CFG" | sort -u)

if [[ ${#SYSTEM_APPIDS[@]} -eq 0 ]]; then
  echo "No system app IDs found. Nothing to block."
  exit 0
fi

# 3) Write the filter file.
OUT="${FILTER_DIR}/${user_remote}.autoblock.filter"
{
  echo "# Auto-generated from ${CFG}"
  echo "# Blocks apps shipped at system scope so they don’t show from the user remote (${user_remote})."
  for id in "${SYSTEM_APPIDS[@]}"; do
    [[ -n "$id" ]] && echo "deny app/${id}/*"
  done
  echo "allow *"
} > "$OUT"

echo "Wrote ${OUT} (user remote: ${user_remote}; ${#SYSTEM_APPIDS[@]} entries)."
