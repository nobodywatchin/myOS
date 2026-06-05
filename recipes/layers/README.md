# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Shared layers

- `shared/core-base.yml`: cross-distro low-level core baseline shared by every supported image, including PCP live metrics and local history.
- `shared/core.yml`: distro-neutral core tooling shared by every supported image, layered after `shared/core-base.yml` and any distro-family repository setup.
- `shared/admin-overlay.yml`: the distro-neutral admin/operator overlay pulled in via `shared/core.yml` for every image.
- `shared/flatpak-base.yml`: workstation Flatpak package baseline, user/system remotes, shared managed app set, policy payloads, and session environment import hook.
- `shared/flatpak-cleanup.yml`: system-scope Flatpak maintenance helper used by startup hooks and `myos` targets.
- `shared/flatpak-gnome.yml`: GNOME portal backend configuration and GNOME-specific managed Flatpaks.
- `shared/flatpak-gnome-legacy.yml`: Alma 9 GNOME managed Flatpak app delta for apps provided natively on modern GNOME lanes.
- `shared/flatpak-cosmic.yml`: COSMIC portal backend configuration and COSMIC Flatpak remotes.
- `shared/workstation-common.yml`: DE-agnostic workstation substrate.
- `shared/workstation-modern.yml`: shared workstation delta reused by the Alma 10 and Fedora lanes.
- `shared/workstation-gnome.yml`: GNOME workstation layer.
- `shared/workstation-gnome-modern.yml`: shared GNOME app delta reused by the Alma 10 and Fedora lanes.
- `shared/workstation-cosmic.yml`: common COSMIC workstation package list, payloads, and validation.
- `shared/nvidia-base.yml`, `shared/nvidia-common.yml`, `shared/nvidia-open-common.yml`, `shared/nvidia-open.yml`, `shared/nvidia-workstation.yml`: shared NVIDIA lane plumbing, including the NVIDIA PCP PMDA on NVIDIA images only.

## Distro-specific layers

- `alma/core.yml`: Alma-family repository and package-manager setup, including EPEL/CRB enablement and subscription-manager cleanup, required before shared core tooling on Alma-derived images.
- `alma9/core.yml`, `alma10/core.yml`, `fedora/core.yml`: distro-specific core drift layered after the shared core baseline and shared core tooling.
- `alma9/workstation.yml`, `alma10/workstation.yml`, `fedora/workstation.yml`: distro workstation drift layered after the shared workstation substrate.
- `alma9/gnome.yml`, `alma10/gnome.yml`: GNOME-only distro drift where the shared GNOME layers are not enough.
- `alma/cosmic.yml`: Alma-family COSMIC COPR source setup and COPR-backed applets shared by Alma 9 and Alma 10.
- `fedora/cosmic.yml`, `fedora/nvidia-open.yml`: Fedora edge-lane drift.
- `alma9/nvidia-580.yml`: the Alma 9 implementation of the public NVIDIA 580 lane.

## Feature layers

`features/` holds optional add-ons that belong to active supported images but still deserve an explicit composition boundary.
