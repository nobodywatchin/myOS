# Update System Flatpaks and OS Image
update-system:
  sudo flatpak update --system -y
  sudo bootc upgrade
  @echo "bootc auto-apply is disabled in myOS; reboot during your maintenance window to activate the staged image update"

# Update User Flatpaks and Distrobox Containers
update-user:
    #!/usr/bin/env bash
    set -euo pipefail

    repair_distrobox_helper_paths() {
      local backup_path config config_dir helper needle new_path old_path replacement repaired_any

      config_dir="${XDG_DATA_HOME:-$HOME/.local/share}/containers/storage/overlay-containers"
      [ -d "$config_dir" ] || return 0

      repaired_any=0
      while IFS= read -r -d '' config; do
        backup_path="${config}.myos-distrobox-helper-paths.bak"

        for helper in distrobox-export distrobox-host-exec distrobox-init; do
          old_path="/usr/sbin/${helper}"
          new_path="/usr/bin/${helper}"
          needle=$(printf '"source":"%s"' "$old_path")
          replacement=$(printf '"source":"%s"' "$new_path")
          if [ -x "$old_path" ] || [ ! -x "$new_path" ]; then
            continue
          fi

          if ! grep -qF "$needle" "$config"; then
            continue
          fi

          if [ ! -f "$backup_path" ]; then
            cp "$config" "$backup_path"
          fi

          sed -i "s#$needle#$replacement#g" "$config"
          printf "Repaired stale %s mount in %s\n" "$helper" "$config"
          repaired_any=1
        done
      done < <(find "$config_dir" -path "*/userdata/config.json" -print0)

      if [ "$repaired_any" -eq 1 ]; then
        echo "Updated stale rootless distrobox helper paths before running upgrades."
      fi
    }

    is_workstation_image() {
      [ -f /etc/profile.d/flatpak-user-default.sh ]
    }

    update_homebrew() {
      local brew_bin brew_owner brew_prefix current_uid

      if ! is_workstation_image; then
        return 0
      fi

      brew_prefix="/home/linuxbrew/.linuxbrew"
      brew_bin="${brew_prefix}/bin/brew"

      if [ ! -x "$brew_bin" ]; then
        return 0
      fi

      current_uid="$(id -u)"
      brew_owner="$(stat -c '%u' "$brew_prefix" 2>/dev/null || true)"
      if [ -n "$brew_owner" ] && [ "$current_uid" != "$brew_owner" ]; then
        printf "Skipping Homebrew update: %s is owned by UID %s, current UID is %s.\n" \
          "$brew_prefix" "$brew_owner" "$current_uid"
        return 0
      fi

      eval "$("$brew_bin" shellenv)"
      "$brew_bin" update
      "$brew_bin" upgrade
    }

    flatpak update --user -y
    update_homebrew
    repair_distrobox_helper_paths
    distrobox-upgrade --all

# Update Podman Containers
update-podman:
  podman image prune -f
  podman auto-update --authfile ~/.config/containers/auth.json

# Update Firmware
update-firmware:
  sudo fwupdmgr refresh --force
  sudo fwupdmgr get-updates
  sudo fwupdmgr update

# Update Everything
update-all:
  myos update-system
  myos update-user
  myos update-podman
  myos update-firmware

# Update Chooser
update:
    #!/usr/bin/env bash
    set -euo pipefail
    sel="$(fzf --prompt='Update: ' --height=15 --border --exit-0 \
          --with-nth=2.. \
          <<< $'update-system    Update System Flatpaks and OS Image\nupdate-user      Update User Flatpaks and Distrobox Containers\nupdate-podman    Update Podman Containers\nupdate-firmware  Update Firmware\nupdate-all       Update Everything\n')"
    [[ -n "$sel" ]] || { echo "No selection."; exit 0; }
    target="${sel%% *}"
    echo "→ Running: just ${target}"
    exec myos "${target}"
