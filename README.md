<p align="center">
  <a href="https://github.com/nobodywatchin/myOS">
    <img src="/files/shared/usr/share/pixmaps/fedora-logo.png" href="https://github.com/nobodywatchin/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/nobodywatchin/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/nobodywatchin/myOS/actions/workflows/build.yml)

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
### AlmaLinux
- `alma10`
- `alma10-nvidia`
- `alma9`
- `alma9-nvidia`
### CentOS 
- 
### Fedora
- `fedora42`
- `fedora42-nvidia`
## Experimental [NOT YET RECOMMENDED]
- 
