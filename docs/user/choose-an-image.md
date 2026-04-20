# Choose An Image

Public image names follow this grammar:

- `<platform>-<environment>`
- `<platform>-<environment>-<driver>`

Choose in this order.

## 1. Pick a lane

- `alma9`: NVIDIA 580 compatibility lane
- `alma10`: stable lane
- `fedora43`: edge lane

## 2. Pick an environment

- `gnome`: the default documented workstation experience
- `cosmic`: a parallel supported workstation experience
- `server`: the headless admin/operator lane

## 3. Pick a driver lane if the distro lane supports one

- images without a driver suffix are the standard lane
- `nvidia-open`: newer supported NVIDIA GPUs on supported Alma 10 and Fedora 43 images
- `nvidia-580`: Alma 9 only, for the supported proprietary R580 lane

## Supported images

The exact supported image list comes from `files/base/runtime/usr/share/myos/image-matrix.tsv`; `myos rebase` downloads that matrix from GitHub when it builds the picker.

Current lanes:

- `alma9`: `alma9-gnome-nvidia-580`, `alma9-cosmic-nvidia-580`, `alma9-server-nvidia-580`
- `alma10`: `alma10-gnome`, `alma10-gnome-nvidia-open`, `alma10-cosmic`, `alma10-cosmic-nvidia-open`, `alma10-server`, `alma10-server-nvidia-open`
- `fedora43`: `fedora43-gnome`, `fedora43-gnome-nvidia-open`, `fedora43-cosmic`, `fedora43-cosmic-nvidia-open`, `fedora43-server`

Unsupported combinations are intentional.

- no console images
- no workstation full split
- no Alma 9 standard or `nvidia-open` images
- no `fedora43-server-nvidia-open`

## Published tag examples

- Stable GNOME workstation on Alma 10: `alma10-gnome`
- Stable COSMIC workstation on Alma 10 with the open NVIDIA lane: `alma10-cosmic-nvidia-open`
- Edge GNOME workstation on Fedora 43: `fedora43-gnome`
- NVIDIA 580 GNOME workstation on Alma 9: `alma9-gnome-nvidia-580`
- Stable server on Alma 10: `alma10-server`
- Edge server on Fedora 43: `fedora43-server`

`myos rebase` shows the full list grouped by role, environment, platform, and driver.
