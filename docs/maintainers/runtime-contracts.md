# Runtime Contracts

The purpose of the refactor is to keep layer ownership explicit while simplifying the public image model.

## Cross-distro core contract

`recipes/layers/shared/core-base.yml` owns behavior that should exist on every supported image, regardless of distro lane.

That includes:

- common core packages and runtime defaults
- branding and `os-release` metadata
- k3s binary, k3s server/agent service units, and shared kernel/network prerequisites through `recipes/layers/features/k3s.yml`
- Tailscale system daemon baseline
- host Vulkan userland/tooling
- the `openquad` command and its supporting runtime-core library files
- the shipped per-user OpenClaw template under `files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/`

## Distro core deltas

- `recipes/layers/shared/core.yml` owns Alma-family core delta such as EPEL/CRB enablement and EL-only package drift.
- `recipes/layers/fedora43/core.yml` owns Fedora 43 edge-lane core delta such as `dnf5-plugins`, Fedora-native ROCm packages, and Fedora-specific package drift.
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml` own only the remaining Alma-lane drift that does not belong in the shared Alma core layer.

## Server/admin contract

`recipes/layers/shared/full.yml` is the explicit server/admin layer.

It owns:

- Cockpit admin surface
- OpenTofu and Kubernetes CLI
- shared Ceph host config baseline; distro-specific Ceph/RBD module and LVM package drift stays in each server lane's `ceph-host.yml`
- tenant runtime helpers and templates
- persistent-user admin helpers and templates
- `openclaw-host`
- shared server/admin filesystem scaffolding under `/etc/myos`, `/srv/tenants`, and `/var/tmp/myos-podman`

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

## Workstation contract

`recipes/layers/shared/workstation-common.yml` owns only the DE-agnostic workstation substrate.

That includes:

- workstation packages and desktop-oriented diagnostics
- boot target selection
- shared display-manager reconciliation

`recipes/layers/shared/workstation-modern.yml` owns the extra workstation delta shared by the Alma 10 and Fedora 43 lanes.

## Workstation environment contract

GNOME and COSMIC are workstation-environment implementations.

- `workstation-gnome.yml` owns GNOME session, extension, and Software integration behavior; `flatpak-gnome.yml` owns GNOME portal selection and GNOME-specific Flatpaks.
- `workstation-gnome-modern.yml` owns the extra GNOME app delta shared by the Alma 10 and Fedora 43 lanes.
- `workstation-cosmic.yml` owns common COSMIC session, greeter, and validation; `flatpak-cosmic.yml` owns COSMIC portal selection and COSMIC Flatpak remotes; `alma/cosmic.yml` and `fedora43/cosmic.yml` own distro source/config drift.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.

## NVIDIA contract

- `shared/nvidia-base.yml` owns the common NVIDIA repo bootstrap, copied config, NVIDIA PCP PMDA registration, and kernel args.
- `shared/nvidia-open-common.yml` owns the open-driver helper shim.
- `shared/nvidia-common.yml` and `shared/nvidia-open.yml` own the Alma-family NVIDIA lanes.
- `fedora43/nvidia-open.yml` owns only the Fedora-specific open-driver delta on top of the shared NVIDIA layers.
