#!/usr/bin/env bash
# Combine "attach filter" + "curated remote" model for GNOME Software
# Reads /usr/share/bluebuild/default-flatpaks/configuration.yaml

set -euo pipefail

CFG="/usr/share/bluebuild/default-flatpaks/configuration.yaml"
FILTER="$(ls /etc/flatpak/filters/*.autoblock.filter 2>/dev/null | head -n1 || true)"
[[ -n "$FILTER" ]] || { echo "No autoblock filter found at /etc/flatpak/filters/*.autoblock.filter"; exit 0; }

# Parse user-remote name + url from the module config
USER_REMOTE="$(
  awk 'BEGIN{u=0} /^- /{u=0} /^[[:space:]]*scope:[[:space:]]*user/{u=1}
       u && /^[[:space:]]*name:/{sub(/.*name:[[:space:]]*/,""); gsub(/["'\''"]/,""); print; exit}' \
  "$CFG" 2>/dev/null || echo flathub
)"
USER_URL="$(
  awk 'BEGIN{u=0} /^- /{u=0} /^[[:space:]]*scope:[[:space:]]*user/{u=1}
       u && /^[[:space:]]*url:/{sub(/.*url:[[:space:]]*/,"");  gsub(/["'\''"]/,""); print; exit}' \
  "$CFG" 2>/dev/null || echo https://dl.flathub.org/repo/flathub.flatpakrepo
)"
CURATED="${USER_REMOTE}-curated"

echo "User remote: $USER_REMOTE"
echo "Curated remote: $CURATED"
echo "Filter: $FILTER"
echo "URL: $USER_URL"

# System side: keep the managed system remote out of GS enumeration (idempotent)
flatpak --system remote-modify --no-enumerate org-system 2>/dev/null || true
flatpak --system update --appstream || true

# Helper: get blocked IDs from the filter
blocked_ids() {
  awk '/^deny[[:space:]]+app\//{sub(/^deny[[:space:]]+app\//,""); sub(/\/\*$/,""); print}' "$FILTER"
}

# Apply to each real user
for home in /home/*; do
  [[ -d "$home" ]] || continue
  u="$(basename "$home")"
  echo "Applying for user: $u"

  su -l "$u" -s /bin/bash -c "
    set -e
    # Ensure original user remote exists (NAME then URL)
    flatpak --user remote-add --if-not-exists --from \"$USER_REMOTE\" \"$USER_URL\" || true

    # Ensure curated user remote exists
    flatpak --user remote-add --if-not-exists --from \"$CURATED\" \"$USER_URL\" || true

    # Attach filter to curated + mark curated enumerated
    flatpak --user remote-modify --filter=\"$FILTER\" --enumerate \"$CURATED\"

    # Make the original user remote non-enumerated so GS only sees the curated one
    flatpak --user remote-modify --no-enumerate \"$USER_REMOTE\" || true

    # Refresh user AppStream
    flatpak --user update --appstream || true

    # OPTIONAL: remove any existing user duplicates of blocked IDs
    while read -r id; do
      [ -n \"\$id\" ] || continue
      flatpak --user info \"\$id\" >/dev/null 2>&1 && flatpak --user uninstall -y \"\$id\" || true
    done < <( $(typeset -f blocked_ids); blocked_ids )

    # Clear this user's GS caches so changes reflect immediately
    rm -rf \"\$HOME/.cache/gnome-software\"/* \"\$HOME/.local/state/gnome-software\"/* 2>/dev/null || true
  "
done

# Bounce GNOME Software if running (user sessions will repopulate cleanly)
killall gnome-software 2>/dev/null || true

echo "Done. GNOME Software will enumerate only '${CURATED}' with your filter."
