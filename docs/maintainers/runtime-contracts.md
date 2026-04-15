# Runtime Contracts

The purpose of the refactor is to make layer ownership explicit again.

## Shared core contract

`recipes/layers/shared/core.yml` is allowed to own only behavior that should exist on every supported image.

That includes:

- base EL packages and common runtime defaults
- branding and `os-release` metadata
- Tailscale system daemon baseline
- host Vulkan userland/tooling
- ROCm userspace and related shared AMD runtime files
- the `openquad` command and its supporting runtime-core library files
- the shipped per-user OpenClaw template under `files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/`

It must not quietly become the operator/admin layer.

## Full contract

`recipes/layers/shared/full.yml` is the explicit admin/operator tier.

It owns:

- Cockpit admin surface
- OpenTofu and Kubernetes CLI
- tenant runtime helpers and templates
- persistent-user admin helpers and templates
- `openclaw-host`
- full-tier filesystem scaffolding under `/etc/myos`, `/srv/tenants`, and `/var/tmp/myos-podman`

These tools are supported, but they are not the default contract of Workstation core or Console core.

## End-user contract

`recipes/layers/shared/end-user-common.yml` is for end-user runtime and app governance that should appear on Workstation and Console.

It owns:

- Flatpak packaging baseline
- system-vs-user Flatpak policy payloads

Server does not consume this layer.

## Workstation contract

`recipes/layers/shared/workstation-common.yml` owns only the DE-agnostic workstation substrate.

That includes:

- workstation packages and desktop-oriented diagnostics
- boot target selection
- shared display-manager reconciliation
- default system Flatpak app set for workstation images

It does not own DE identity. That identity lives in the workstation family layers.

## Workstation family contract

GNOME and COSMIC are workstation-family implementations.

- `workstation-gnome.yml` owns GNOME session, portal, extension, and Software integration behavior.
- `workstation-cosmic.yml` owns COSMIC session, greeter, and portal behavior.
- `files/gnome/shared/usr/share/myos/workstation/desktop.env` and `files/cosmic/shared/usr/share/myos/workstation/desktop.env` are the family markers consumed by the shared DM helper.

## Console contract

Console currently promises only this:

- Alma 10 only
- core only
- end-user app/runtime model via `end-user-common`
- console preview marker payloads via `files/console/shared/`

Do not document it as a finished gaming shell until the role has its own completed package and validation story.
