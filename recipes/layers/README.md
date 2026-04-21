# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Shared layers

- `shared/core-base.yml`: cross-distro core baseline shared by every supported image, including PCP live metrics and local history.
- `shared/core.yml`: Alma-specific core delta layered on top of `shared/core-base.yml`.
- `shared/full.yml`: the distro-neutral admin/operator layer stacked on top of a distro core.
- `shared/flatpak-base.yml`: workstation Flatpak package baseline, user/system remotes, shared managed app set, policy payloads, and session environment import hook.
- `shared/flatpak-cleanup.yml`: system-scope Flatpak maintenance helper used by startup hooks and `myos` targets.
- `shared/flatpak-gnome.yml`: GNOME portal backend configuration and GNOME-specific managed Flatpaks.
- `shared/flatpak-gnome-legacy.yml`: Alma 9 GNOME managed Flatpak app delta for apps provided natively on modern GNOME lanes.
- `shared/flatpak-cosmic.yml`: COSMIC portal backend configuration and COSMIC Flatpak remotes.
- `shared/workstation-common.yml`: DE-agnostic workstation substrate.
- `shared/workstation-modern.yml`: shared workstation delta reused by the Alma 10 and Fedora 43 lanes.
- `shared/workstation-gnome.yml`: GNOME workstation layer.
- `shared/workstation-gnome-modern.yml`: shared GNOME app delta reused by the Alma 10 and Fedora 43 lanes.
- `shared/workstation-cosmic.yml`: common COSMIC workstation package list, payloads, and validation.
- `shared/nvidia-base.yml`, `shared/nvidia-common.yml`, `shared/nvidia-open-common.yml`, `shared/nvidia-open.yml`, `shared/nvidia-workstation.yml`: shared NVIDIA lane plumbing, including the NVIDIA PCP PMDA on NVIDIA images only.

## Distro-specific layers

- `alma9/core.yml`, `alma10/core.yml`, `fedora43/core.yml`: distro-specific core drift layered on top of the shared core baseline.
- `alma9/workstation.yml`, `alma10/workstation.yml`, `fedora43/workstation.yml`: distro workstation drift layered after the shared workstation substrate.
- `alma9/gnome.yml`, `alma10/gnome.yml`: GNOME-only distro drift where the shared GNOME layers are not enough.
- `alma/cosmic.yml`: Alma-family COSMIC COPR source setup and COPR-backed applets shared by Alma 9 and Alma 10.
- `fedora43/cosmic.yml`, `fedora43/nvidia-open.yml`: Fedora 43 edge-lane drift.
- `alma9/nvidia-580.yml`: the Alma 9 implementation of the public NVIDIA 580 lane.

## Feature layers

`features/` holds optional add-ons that belong to active supported images but still deserve an explicit composition boundary.
