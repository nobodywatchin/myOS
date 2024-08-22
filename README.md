<p align="center">
  <a href="https://github.com/secureblue/secureblue">
    <img src="https://github.com/nobodywatchin/myOS/files/shared/usr/share/pixmaps/fedora-logo-sprite.png" href="https://github.com/secureblue/secureblue" width=180 />
  </a>
</p>

<h1 align="center">secureblue</h1>

This repo uses [BlueBuild](https://blue-build.org/) to generate hardened operating system images, using [uBlue](https://universal-blue.org)'s [Fedora Atomic](https://fedoraproject.org/atomic-desktops/)-based [base images](https://github.com/orgs/ublue-os/packages?repo_name=main) as a starting point. 

# Scope

myOS is a custom universal blue image dedicated to progress, freedom, and ease-of-use.

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

# Images <sup>[userns?](USERNS.md)</sup>
## Desktop
### Recommended <sup>[why?](RECOMMENDED.md)</sup>
- `myos-gnome`
- `myos-kde`
### Experimental
- `myos-cosmic`
- `myos-hyprland`
### NVIDIA 
- `myos-gnome-nvidia`
- `myos-kde-nvidia`
- `myos-cosmic-nvidia`
- `myos-hyprland-nvidia`
### Intel Macbook
- `myos-gnome-intel-mac`
- `myos-kde-intel-mac`
- `myos-cosmic-intel-mac`
- `myos-hyprland-intel-mac`
### Surface 
- `myos-gnome-surface`
- `myos-kde-surface`
- `myos-cosmic-surface`
- `myos-hyprland-surface`
## Server
- `myos-headless`
