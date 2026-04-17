# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Shared layers

- `shared/core-base.yml`: cross-distro core baseline shared by every supported image.
- `shared/core.yml`: Alma-specific core delta layered on top of `shared/core-base.yml`.
- `shared/full.yml`: the distro-neutral admin/operator layer stacked on top of a distro core.
- `shared/end-user-common.yml`: Flatpak governance and end-user runtime pieces shared by workstation images.
- `shared/workstation-common.yml`: DE-agnostic workstation substrate.
- `shared/workstation-modern.yml`: shared workstation delta reused by the Alma 10 and Fedora 43 lanes.
- `shared/workstation-gnome.yml`: GNOME workstation layer.
- `shared/workstation-gnome-modern.yml`: shared GNOME app delta reused by the Alma 10 and Fedora 43 lanes.
- `shared/workstation-cosmic.yml`: COSMIC workstation layer.
- `shared/nvidia-base.yml`, `shared/nvidia-common.yml`, `shared/nvidia-open-common.yml`, `shared/nvidia-open.yml`, `shared/nvidia-workstation.yml`: shared NVIDIA lane plumbing.

## Distro-specific layers

- `alma9/core.yml`, `alma10/core.yml`, `fedora43/core.yml`: distro-specific core drift layered on top of the shared core baseline.
- `alma9/workstation.yml`, `alma10/workstation.yml`, `fedora43/workstation.yml`: distro workstation drift layered after the shared workstation substrate.
- `alma9/gnome.yml`, `alma10/gnome.yml`: GNOME-only distro drift where the shared GNOME layers are not enough.
- `fedora43/cosmic.yml`, `fedora43/nvidia-open.yml`: Fedora 43 edge-lane drift.
- `alma9/nvidia-580.yml`: the Alma 9 implementation of the public NVIDIA 580 lane.

## Feature layers

`features/` holds optional add-ons that belong to active supported images but still deserve an explicit composition boundary.
