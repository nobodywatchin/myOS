# Runtime Contracts

The purpose of the refactor is to keep layer ownership explicit while simplifying the public image model.

## Cross-distro core contract

`recipes/layers/shared/core-base.yml` owns the low-level baseline shared by every supported image.

That includes:

- common core packages and runtime defaults
- branding and `os-release` metadata
- host Vulkan userland/tooling where supported by the platform lane
- base runtime files and shared Justfile command surface
- inclusion of cross-image feature and policy layers

`recipes/layers/shared/core-base.yml` should not grow into a catch-all layer. Shared features with their own policy surface should live in explicit feature or policy layers.

Current delegated layers:

- `recipes/layers/features/k3s.yml`: k3s binary and disabled server/agent unit baseline
- `recipes/layers/features/pcp.yml`: PCP local metrics collection and history
- `recipes/layers/features/tailscale.yml`: Tailscale package and daemon baseline
- `recipes/layers/shared/system-policy.yml`: shared groups, kernel args, and masked update/counting services

`recipes/layers/shared/core.yml` owns the small distro-neutral host/operator package baseline shared by every supported image. It runs after `shared/core-base.yml` and any distro-family repository setup needed to make the shared package set available.

ROCm userspace is not a universal cross-image promise. It belongs to the platform lanes that can support the package set cleanly, currently Alma 10 and Fedora. Alma 9 should remain focused on the NVIDIA 580 compatibility lane.

## Distro core deltas

- `recipes/layers/alma/core.yml` owns Alma-family repository setup such as EPEL/CRB enablement and subscription-manager cleanup.
- `recipes/layers/fedora/core.yml` owns the Fedora edge-lane delta such as `dnf5-plugins`, Fedora-native ROCm packages, and Fedora-specific package drift.
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml` own only the remaining Alma-version drift that does not belong in the shared Alma-family layer.
- `recipes/layers/alma10/core.yml` may carry ROCm-related Alma 10 enablement when that support belongs to the Alma 10 lane rather than the cross-distro contract.

## Feature overlays and shared remainder

`recipes/layers/features/cockpit.yml` owns the Cockpit admin surface.

`recipes/layers/features/ceph.yml` owns the shared Ceph host prerequisites.

`recipes/layers/features/k3s.yml` owns shared k3s runtime capability.

`recipes/layers/features/pcp.yml` owns shared PCP runtime capability.

`recipes/layers/features/tailscale.yml` owns shared Tailscale runtime capability.

`recipes/layers/shared/system-policy.yml` owns shared system policy that is not tied to one distro or role.

`recipes/layers/shared/core.yml` owns the remaining host/operator package baseline:

- fastfetch, fzf, zstd, gcc, distrobox, and podman-compose
- generic `/etc/myos` filesystem scaffolding and `/usr/share/current` compatibility exposure for shared runtime payloads
- inclusion of Cockpit and Ceph feature overlays

## Flatpak contract

`recipes/layers/shared/flatpak-base.yml` is for workstation Flatpak runtime and app governance.

It owns:

- Flatpak and `xdg-desktop-portal` package baseline
- user `flathub` remote for personal installs
- hidden admin-managed `org-system` remote for curated system apps and dependency resolution
- shared managed system app set
- Flatpak policy payloads under `files/flatpak/base/`
- graphical session environment import for D-Bus activation and `systemd --user`

`recipes/layers/shared/flatpak-cleanup.yml` owns the system-scope maintenance helper used by startup hooks and Justfile targets.

`recipes/layers/shared/flatpak-gnome.yml` and `recipes/layers/shared/flatpak-cosmic.yml` own desktop portal backend selection and environment-specific Flatpak remotes/apps.

Server recipes do not consume these layers and should not receive desktop portal backend logic.

The system Flatpak model is intentionally opinionated. It reduces drift on multi-user workstations by keeping curated shared apps separate from each user's personal `flathub` installs.

## Workstation contract

`recipes/layers/shared/workstation-common.yml` is the DE-agnostic workstation orchestrator.

It should stay small and delegate real ownership to explicit sublayers:

- `workstation-substrate.yml`: shared desktop, hardware, audio, printing, scanning, camera, input, language, and base workstation packages
- `workstation-admin-tools.yml`: workstation-only diagnostics, storage, network, and admin utilities
- `workstation-policy.yml`: graphical target, display-manager reconciliation, and workstation sleep policy
- `workstation-user-tools.yml`: opinionated user-facing workstation tooling such as Homebrew and Brave Origin Beta

`recipes/layers/shared/workstation-modern.yml` owns the extra workstation delta shared by the Alma 10 and Fedora lanes.

Workstation images are the operator desktop and laptop lane. They should remain useful as normal desktop systems while still sharing the same image-based operating model as the server and lab lanes.

## Workstation environment contract

GNOME and COSMIC are workstation-environment implementations.

- `workstation-gnome.yml` owns GNOME session, extension, and Software integration behavior; `flatpak-gnome.yml` owns GNOME portal selection and GNOME-specific Flatpaks.
- `workstation-gnome-modern.yml` owns the extra GNOME app delta shared by the Alma 10 and Fedora lanes.
- `workstation-cosmic.yml` owns common COSMIC session, greeter, and validation; `flatpak-cosmic.yml` owns COSMIC portal selection and COSMIC Flatpak remotes; `alma/cosmic.yml` and `fedora/cosmic.yml` own distro source/config drift.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.

## NVIDIA contract

- `shared/nvidia-base.yml` owns the common NVIDIA repo bootstrap, NVIDIA container toolkit setup, NVIDIA PCP PMDA package, copied NVIDIA support payloads, and kernel args.
- `shared/nvidia-open-common.yml` owns the open-driver helper shim.
- `shared/nvidia-common.yml` and `shared/nvidia-open.yml` own the Alma-family NVIDIA lanes.
- `fedora/nvidia-open.yml` owns only the Fedora-specific open-driver delta on top of the shared NVIDIA layers.

## Current compatibility namespace

`current` is the primary command wrapper. `myos` remains a compatibility alias that execs `current`.

Runtime payloads remain sourced from `/usr/share/myos` in the repo and installed image, with `/usr/share/current` exposed as a symlink for Current-native consumers. `CURRENT_*` environment variables take precedence over matching `MYOS_*` fallback variables in migration-aware scripts.
