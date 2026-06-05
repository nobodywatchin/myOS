# Runtime Contracts

The purpose of the refactor is to keep layer ownership explicit while simplifying the public image model.

## Cross-distro core contract

`recipes/layers/shared/core-base.yml` owns low-level behavior that should exist on every supported image, regardless of distro lane.

That includes:

- common core packages and runtime defaults
- branding and `os-release` metadata
- k3s binary, k3s server/agent service units, and shared kernel/network prerequisites through `recipes/layers/features/k3s.yml`
- Tailscale system daemon baseline
- host Vulkan userland/tooling
- shared runtime-core helper libraries, `myos cluster`, and AMD/ROCm access prerequisites

`recipes/layers/shared/core.yml` owns distro-neutral core tooling shared by every supported image. It runs after `shared/core-base.yml` and any distro-family repository setup needed to make the shared package set available.

## Distro core deltas

- `recipes/layers/alma/core.yml` owns Alma-family repository setup such as EPEL/CRB enablement and subscription-manager cleanup.
- `recipes/layers/fedora/core.yml` owns Fedora edge-lane core delta such as `dnf5-plugins`, Fedora-native ROCm packages, and Fedora-specific package drift.
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml` own only the remaining Alma-version drift that does not belong in the shared Alma-family layer.

## Feature overlays and shared remainder

`recipes/layers/features/cockpit.yml` owns the Cockpit admin surface.

`recipes/layers/features/ceph.yml` owns the shared Ceph host prerequisites.

`recipes/layers/features/k3s.yml` owns the shared k3s runtime capability.

`recipes/layers/shared/core.yml` owns the remaining shared host/operator remainder:

- OpenTofu and Kubernetes CLI
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

`recipes/layers/shared/workstation-modern.yml` owns the extra workstation delta shared by the Alma 10 and Fedora lanes.

## Workstation environment contract

GNOME and COSMIC are workstation-environment implementations.

- `workstation-gnome.yml` owns GNOME session, extension, and Software integration behavior; `flatpak-gnome.yml` owns GNOME portal selection and GNOME-specific Flatpaks.
- `workstation-gnome-modern.yml` owns the extra GNOME app delta shared by the Alma 10 and Fedora lanes.
- `workstation-cosmic.yml` owns common COSMIC session, greeter, and validation; `flatpak-cosmic.yml` owns COSMIC portal selection and COSMIC Flatpak remotes; `alma/cosmic.yml` and `fedora/cosmic.yml` own distro source/config drift.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.

## NVIDIA contract

- `shared/nvidia-base.yml` owns the common NVIDIA repo bootstrap, copied config, NVIDIA PCP PMDA registration, and kernel args.
- `shared/nvidia-open-common.yml` owns the open-driver helper shim.
- `shared/nvidia-common.yml` and `shared/nvidia-open.yml` own the Alma-family NVIDIA lanes.
- `fedora/nvidia-open.yml` owns only the Fedora-specific open-driver delta on top of the shared NVIDIA layers.
