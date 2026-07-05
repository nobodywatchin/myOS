# Choose An Image

Current is an image ecosystem. Choose the image that best matches the machine's hardware and workflow.

Public image names follow this technical grammar:

- `<platform>-<environment>`
- `<platform>-<environment>-<driver>`

Choose in this order.

## 1. Pick a lane

- `alma9`: NVIDIA 580 compatibility lane
- `alma10`: stable lane
- `fedora`: edge lane

## 2. Pick an environment

- `gnome`: the default documented workstation experience
- `cosmic`: a parallel supported workstation experience
- `server`: the headless admin/operator lane

## 3. Pick a driver lane if the distro lane supports one

- images without a driver suffix are the standard lane
- `nvidia-open`: newer supported NVIDIA GPUs on supported Alma 10 and Fedora images
- `nvidia-580`: Alma 9 only, for the supported proprietary R580 lane

## Supported images

The exact supported image list comes from `files/base/runtime/usr/share/myos/image-matrix.tsv`; `current rebase` downloads that matrix from GitHub when it builds the picker. Installed systems also expose it through `/usr/share/current` for the Current-native path.

Current lanes:

- `alma9`: `alma9-gnome-nvidia-580`, `alma9-cosmic-nvidia-580`, `alma9-server-nvidia-580`
- `alma10`: `alma10-gnome`, `alma10-gnome-nvidia-open`, `alma10-cosmic`, `alma10-cosmic-nvidia-open`, `alma10-server`, `alma10-server-nvidia-open`
- `fedora`: `fedora-gnome`, `fedora-gnome-nvidia-open`, `fedora-cosmic`, `fedora-cosmic-nvidia-open`, `fedora-server`

Unsupported combinations are intentional.

- no Alma 9 standard or `nvidia-open` images
- no `fedora-server-nvidia-open`

## Published tag examples

- Current AlmaLinux 10 GNOME workstation: `alma10-gnome`
- Current AlmaLinux 10 COSMIC workstation with the open NVIDIA lane: `alma10-cosmic-nvidia-open`
- Current Fedora GNOME workstation: `fedora-gnome`
- Current AlmaLinux 9 NVIDIA 580 GNOME workstation: `alma9-gnome-nvidia-580`
- Current AlmaLinux 10 Server: `alma10-server`
- Current Fedora Server: `fedora-server`

`current rebase` shows the full list grouped by role, environment, platform, and driver. `myos rebase` remains a compatibility alias.
