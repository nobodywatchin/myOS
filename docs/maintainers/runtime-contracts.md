# Runtime Contracts

The purpose of the refactor is to keep layer ownership explicit while simplifying the public image model.

## Shared core contract

`recipes/layers/shared/core.yml` is allowed to own only behavior that should exist on every supported Alma image.

That includes:

- base EL packages and common runtime defaults
- branding and `os-release` metadata
- Tailscale system daemon baseline
- host Vulkan userland/tooling
- ROCm userspace and related shared AMD runtime files
- the `openquad` command and its supporting runtime-core library files
- the shipped per-user OpenClaw template under `files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/`

It must not quietly become the operator/admin layer.

## Admin/operator contract

`recipes/layers/shared/full.yml` is the explicit admin/operator layer.

It owns:

- Cockpit admin surface
- OpenTofu and Kubernetes CLI
- tenant runtime helpers and templates
- persistent-user admin helpers and templates
- `openclaw-host`
- shared admin/operator filesystem scaffolding under `/etc/myos`, `/srv/tenants`, and `/var/tmp/myos-podman`

This layer is internal composition, not a user-facing product split. It should stay safe to apply on top of either the Alma or Fedora core contracts.

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
- default system Flatpak app set for workstation images

It does not own DE identity. That identity lives in the workstation family layers.

## Workstation family contract

GNOME and COSMIC are workstation-environment implementations.

- `workstation-gnome.yml` owns GNOME session, portal, extension, and Software integration behavior.
- `workstation-cosmic.yml` owns COSMIC session, greeter, and portal behavior.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.
