<p align="center">
  <a href="https://github.com/nobodywatchin/myOS">
    <img src="https://github.com/nobodywatchin/myOS/files/shared/usr/share/pixmaps/bootloader/fedora.icns" href="https://github.com/nobodywatchin/myOS" width=180 />
  </a>
</p>

<h1 align="center">myOS</h1>

myOS is an opinionated all-purpose operating system dedicated to progress, freedom, and ease-of-use.

# How it's made

This repo uses [BlueBuild](https://blue-build.org/) to generate operating system images, using [uBlue](https://universal-blue.org)'s [Fedora Atomic](https://fedoraproject.org/atomic-desktops/)-based [images](https://github.com/orgs/ublue-os/packages?repo_name=main) as a starting point. 

# Vision

myOS was created to offer a user-friendly yet powerful operating system that embraces open-source principles while providing a cohesive and polished experience. 

myOS works out of the box with minimal setup, allowing users to focus on their tasks without unnecessary distractions.

# Customization

If you want to add your own customizations on top of myOS, you are advised strongly against forking. Instead, create a repo for your own image by using the [BlueBuild template](https://github.com/blue-build/template), then change your `base-image` to a myOS image. This will allow you to apply your customizations to myOS in a concise and maintainable way, without the need to constantly sync with upstream. 

# Installation

## Rebasing (Recommended)

To rebase a Fedora Atomic installation, choose an $IMAGE_NAME from the [list below](README.md#images-userns), then follow these steps:

*(Important note: the **only** supported tag is `latest`)*

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/nobodywatchin/$IMAGE_NAME:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/nobodywatchin/$IMAGE_NAME:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

# Images
### Recommended
- `myos-gnome`
- `myos-kde`
### NVIDIA 
- `myos-gnome-nvidia`
- `myos-kde-nvidia`
### Intel Macbook
- `myos-gnome-intel-mac`
- `myos-kde-intel-mac`
### Surface 
- `myos-gnome-surface`
- `myos-kde-surface`
## Experimental [NOT YET RECOMMENDED]
- `myos-cosmic`
- `myos-hyprland`
- `myos-cosmic-nvidia`
- `myos-hyprland-nvidia`
- `myos-cosmic-intel-mac`
- `myos-hyprland-intel-mac`
## Server
- `myos-headless`
