# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Shared layers

- `shared/core.yml`: the common base for every Alma image.
- `shared/full.yml`: the distro-neutral admin/operator layer stacked on top of a distro core.
- `shared/end-user-common.yml`: Flatpak governance and end-user runtime pieces shared by workstation images.
- `shared/workstation-common.yml`: DE-agnostic workstation substrate.
- `shared/workstation-gnome.yml`: GNOME workstation layer.
- `shared/workstation-cosmic.yml`: COSMIC workstation layer.
- `shared/nvidia-common.yml`, `shared/nvidia-open.yml`, `shared/nvidia-workstation.yml`: shared NVIDIA lane plumbing.

## Distro-specific layers

- `alma9/core.yml`, `alma10/core.yml`: distro-specific core drift.
- `alma9/full.yml`, `alma10/full.yml`: distro-specific server/admin drift layered after `shared/full.yml`.
- `alma9/workstation.yml`, `alma10/workstation.yml`: distro workstation drift shared by GNOME and COSMIC.
- `alma9/gnome.yml`, `alma10/gnome.yml`: GNOME-only distro drift.
- `fedora43/core.yml`, `fedora43/workstation.yml`, `fedora43/gnome.yml`, `fedora43/cosmic.yml`, `fedora43/nvidia-open.yml`: the Fedora 43 edge lane.
- `alma9/nvidia-legacy.yml`: the internal Alma 9 implementation of the public NVIDIA 580 lane.

## Feature layers

`features/` holds optional add-ons that should not silently expand the default role contracts.

That includes `features/rocm-developer-tools.yml` for heavier ROCm tooling that does not belong in every supported image.
