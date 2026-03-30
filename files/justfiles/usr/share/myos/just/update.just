# Update System Flatpaks and OS Image
update-system:
  sudo flatpak update --system -y
  sudo bootc upgrade
  @echo "bootc auto-apply is disabled in myOS; reboot during your maintenance window to activate the staged image update"

# Update User Flatpaks and Distrobox Containers
update-user:
  flatpak update --user -y
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
