# myOS

myOS is a custom universal blue image dedicated to progress, freedom, and ease-of-use.

## Installation

To rebase an existing atomic Fedora (or Universal Blue) installation to the latest build:
- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/nobodywatchin/myos-gnome:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/nobodywatchin/myos-gnome:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
