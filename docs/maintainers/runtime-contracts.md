# Runtime Contracts

The purpose of the refactor is to keep layer ownership explicit while simplifying the public image model.

## Cross-distro core contract

`recipes/layers/shared/core-base.yml` owns behavior that should exist on every supported image, regardless of distro lane.

That includes:

- common core packages and runtime defaults
- branding and `os-release` metadata
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
- tenant runtime helpers and templates
- persistent-user admin helpers and templates
- `openclaw-host`
- shared server/admin filesystem scaffolding under `/etc/myos`, `/srv/tenants`, and `/var/tmp/myos-podman`

## End-user contract

`recipes/layers/shared/end-user-common.yml` is for workstation runtime and app governance.

It owns:

- Flatpak packaging baseline
- system-vs-user Flatpak policy payloads

Server recipes do not consume this layer.

## Workstation contract

`recipes/layers/shared/workstation-common.yml` owns only the DE-agnostic workstation substrate.

That includes:

- workstation packages and desktop-oriented diagnostics
- boot target selection
- shared display-manager reconciliation
- the common user/system Flatpak remotes and shared workstation app set

`recipes/layers/shared/workstation-modern.yml` owns the extra workstation delta shared by the Alma 10 and Fedora 43 lanes.

## Workstation environment contract

GNOME and COSMIC are workstation-environment implementations.

- `workstation-gnome.yml` owns GNOME session, portal, extension, and Software integration behavior.
- `workstation-gnome-modern.yml` owns the extra GNOME app delta shared by the Alma 10 and Fedora 43 lanes.
- `workstation-cosmic.yml` owns common COSMIC session, greeter, portal, validation, and COSMIC Flatpak behavior; `alma/cosmic.yml` and `fedora43/cosmic.yml` own distro source/config drift.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.

## NVIDIA contract

- `shared/nvidia-base.yml` owns the common NVIDIA repo bootstrap, copied config, NVIDIA PCP PMDA registration, and kernel args.
- `shared/nvidia-open-common.yml` owns the open-driver helper shim.
- `shared/nvidia-common.yml` and `shared/nvidia-open.yml` own the Alma-family NVIDIA lanes.
- `fedora43/nvidia-open.yml` owns only the Fedora-specific open-driver delta on top of the shared NVIDIA layers.
