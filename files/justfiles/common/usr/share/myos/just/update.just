# Update System Flatpaks and OS Image
update-system:
  sudo bootc upgrade
  @echo "Reboot to apply system updates"

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
  just update-system
  just update-podman
  just update-firmware
