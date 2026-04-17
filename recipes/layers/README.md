# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Shared layers

- `shared/core.yml`: the common base for every role and tier.
- `shared/full.yml`: the explicit admin/operator tier.
- `shared/end-user-common.yml`: Flatpak governance and end-user runtime pieces shared by Workstation and Console.
- `shared/workstation-common.yml`: DE-agnostic workstation substrate.
- `shared/workstation-gnome.yml`: GNOME workstation family layer.
- `shared/workstation-cosmic.yml`: COSMIC workstation family layer.
- `shared/console.yml`: Alma 10 Console preview role layer.
- `shared/nvidia-common.yml`, `shared/nvidia-open.yml`, `shared/nvidia-workstation.yml`: shared NVIDIA lane plumbing.

## Distro-specific layers

- `alma9/core.yml`, `alma10/core.yml`: distro-specific core drift.
- `alma9/full.yml`, `alma10/full.yml`: distro-specific full-tier drift.
- `alma9/workstation.yml`, `alma10/workstation.yml`: distro workstation drift shared by GNOME and COSMIC.
- `alma9/gnome.yml`, `alma10/gnome.yml`: GNOME-only distro drift.
- `fedora43/core.yml`, `fedora43/workstation.yml`, `fedora43/gnome.yml`, `fedora43/cosmic.yml`, `fedora43/nvidia-open.yml`: the initial Fedora 43 workstation-core lane.
- `alma9/nvidia-legacy.yml`: Alma 9-only proprietary legacy NVIDIA lane.

## Feature layers

`features/` holds optional add-ons that should not silently expand the default role or tier contracts.

That now includes `features/rocm-developer-tools.yml` for heavier ROCm tooling that no longer belongs in every workstation image.
