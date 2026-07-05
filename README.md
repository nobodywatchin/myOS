<p align="center">
  <a href="https://github.com/Pelagians/Current">
    <img src="docs/brand/assets/current-wordmark.svg" alt="Current" width="420" />
  </a>
</p>

# Current &nbsp; [![BlueBuild build badge](https://github.com/Pelagians/Current/actions/workflows/build.yml/badge.svg)](https://github.com/Pelagians/Current/actions/workflows/build.yml)

Current is an open-source ecosystem of immutable bootc-based Linux images for developers.

It is container-first, close to upstream, and intentionally lightweight: just enough system opinion to make modern Linux practical across workstations, servers, labs, and clusters.

Current is not a replacement for Fedora, AlmaLinux, Debian, Arch, Universal Blue, or other Linux ecosystems. It is a curated image layer built on top of excellent upstream systems, asking what they should look like when designed today around image-native updates and container-native workflows.

> **Compatibility status:** `current` is the supported CLI and `/usr/share/current/just` is the command payload source of truth. No `myos` CLI is installed. Legacy image, data-path, and environment transition surfaces such as `ghcr.io/myos-dev/*`, `/usr/share/myos`, and selected `MYOS_*` fallbacks may remain until separately migrated.

## Why Current

Current is built around a small, explicit image matrix instead of endless variants.

- **Image-native:** bootc images are the unit of installation, update, rollback, and remix.
- **Container-first:** applications and services belong in containers whenever practical; the operating system provides a reliable runtime beneath them.
- **Close to upstream:** Current builds on upstream distributions instead of trying to replace them.
- **Just enough opinionated:** sensible defaults, hardware-aware lanes, useful helpers, and practical runtime support without turning every image into an appliance.
- **Developer-first:** Current is designed for developers, especially AI developers, who move between local workstations, servers, and cluster workflows.
- **Explicit hardware policy:** GPU and driver lanes are documented and validated instead of left for users to reverse-engineer.
- **Stable beneath motion:** rebases, rollbacks, and image lanes make movement normal while keeping the base system predictable.

The name **Current** refers to ocean currents: movement and momentum with stability underneath.

## Image ecosystem

Current is an image ecosystem. Users install Current, then choose the image that best matches their hardware and workflow.

Public image names follow this technical grammar:

```text
<platform>-<environment>
<platform>-<environment>-<driver>
```

Product-facing examples include:

- Current Fedora Workstation
- Current Fedora Server
- Current AlmaLinux 10 GNOME
- Current AlmaLinux 9 COSMIC LTS

The exact supported tags live in the shipped manifest:

```text
files/base/runtime/usr/share/myos/image-matrix.tsv
```

The image-matrix source path stays in the legacy location until the data-path migration moves all consumers together. User command Justfiles live under `files/justfiles/usr/share/current/just`.

User-facing image selection docs live here:

- [docs/user/choose-an-image.md](docs/user/choose-an-image.md)

## Supported lanes

Lane summary:

- `alma9`: NVIDIA 580 compatibility only for `gnome`, `cosmic`, and `server`
- `alma10`: stable `gnome`, `cosmic`, and `server`, with optional `nvidia-open`
- `fedora`: edge `gnome`, `cosmic`, and `server`, with optional `nvidia-open` on workstation images

Unsupported by design:

- no console images
- no workstation full split
- no Alma 9 standard images
- no Alma 9 `nvidia-open` images
- no `fedora-server-nvidia-open`

## Workstation model

Current Workstation images are developer desktops built on the same image-native model as Current Server.

They exist so your desktop or laptop can participate in the same operating model as your servers:

- image-based updates
- bootc system images
- container-native workflows
- operator and developer tooling
- predictable workstation rebuilds

GNOME and COSMIC are the supported workstation environments. They are environment implementations under the workstation role, not separate products.

## Server model

Current Server images are the headless infrastructure lane.

They are intended for lab nodes, self-hosted services, operator-managed machines, small internal infrastructure environments, and cluster hosts.

Server images share the same core contract as workstation images where it makes sense, but avoid desktop-specific layering.

## Container and app model

Applications belong in containers whenever practical. The operating system exists to provide a reliable runtime.

Current provides practical host support for Podman, local container workflows, k3s where appropriate, and runtime helpers without baking higher-level services into the OS image.

On workstation images, Current keeps two Flatpak lanes:

- user-managed `flathub` for personal installs
- admin-managed `org-system` for curated shared apps

`org-system` is hidden from normal app and source enumeration, but remains available for system runtime dependency resolution.

Details:

- [docs/user/apps-and-flatpak.md](docs/user/apps-and-flatpak.md)

## AI developer runtime

Current is AI-ready, not AI-bloated.

It gives AI developers practical local host/runtime capability without shipping preloaded models, hosted agents, or branding-theater services.

Shared runtime support includes:

- host Vulkan tooling where supported by the platform lane
- generic Podman capability
- k3s host capability for users who want Kubernetes on their own machines
- ROCm userspace where supported by the current platform lane, currently Alma 10 and Fedora

Higher-level services belong above Current, usually in containers or k3s.

Details:

- [docs/user/ai-ready.md](docs/user/ai-ready.md)

## Install and update

The supported command for installed systems is:

```bash
current rebase
```

The picker is grouped by role, environment, platform, and driver. It downloads the same image matrix from the GitHub repo that CI validates, so supported lanes and published tags stay in sync.

For manual switching:

```bash
sudo bootc switch ghcr.io/pelagians/alma10-gnome:latest
```

Current disables unattended `bootc` auto-apply.

Use:

```bash
current update-system
```

to update managed system Flatpaks, prune unused system Flatpak refs, and stage a bootc image update.

Rebase when you choose. Reboot when you are ready.

More user docs:

- [docs/user/choose-an-image.md](docs/user/choose-an-image.md)
- [docs/user/install.md](docs/user/install.md)
- [docs/user/updates-and-rollbacks.md](docs/user/updates-and-rollbacks.md)
- [docs/user/hardware.md](docs/user/hardware.md)
- [docs/user/release-policy.md](docs/user/release-policy.md)

## Repo layout

```text
recipes/
  images/
    workstation/
    server/
  layers/
    shared/
    alma9/
    alma10/
    fedora/
    features/

files/
  base/
  ceph-host/
  cosmic/
  dnf/
  flatpak/
  gnome/
  justfiles/
  k3s/
  nvidia/
  scripts/
  workstation/
```

The authoritative repo shape stays role-first.

Workstation keeps clean GNOME and COSMIC layering underneath that role, while the shipped manifest decides which combinations are actually supported.

## Docs

Start here:

- [docs/README.md](docs/README.md)

Decision records live under `docs/decisions/`:

- [docs/decisions/0001-myos-to-current-rebrand.md](docs/decisions/0001-myos-to-current-rebrand.md)
- [docs/decisions/0002-current-visual-identity-runtime-branding.md](docs/decisions/0002-current-visual-identity-runtime-branding.md)
- [docs/decisions/0003-current-compatibility-migration.md](docs/decisions/0003-current-compatibility-migration.md)
- [docs/decisions/0004-current-cli-primary-no-myos-command-alias.md](docs/decisions/0004-current-cli-primary-no-myos-command-alias.md)

Compatibility docs live here:

- [docs/compatibility.md](docs/compatibility.md)

Brand identity docs live under `docs/brand/`:

- [docs/brand/visual-identity.md](docs/brand/visual-identity.md)
- [docs/brand/runtime-branding.md](docs/brand/runtime-branding.md)

Maintainer and operator-facing docs live under `docs/maintainers/`:

- [docs/maintainers/image-architecture.md](docs/maintainers/image-architecture.md)
- [docs/maintainers/runtime-contracts.md](docs/maintainers/runtime-contracts.md)
- [docs/maintainers/workstation-layering.md](docs/maintainers/workstation-layering.md)
- [docs/maintainers/validation.md](docs/maintainers/validation.md)
- [docs/maintainers/alma-drift.md](docs/maintainers/alma-drift.md)

## Project boundary

Current is a focused image-based OS project for people who want a practical, reproducible base for developer workstations, servers, lab machines, and cluster hosts.

It is not a hosted application platform, not an AI appliance, and not a replacement for upstream distributions. Higher-level services should run above Current, usually in containers or k3s.

## Current and Pelagian

Current is the preferred operating system used internally throughout Pelagian, but it is not required for Pelagian commercial products.

Nereus and Nyra are Kubernetes-native and distribution-agnostic. Current should stand on its own as an independent open-source project.

## Upstream and BlueBuild

Current depends on excellent upstream distributions and the BlueBuild image build framework.

The project should continue to credit BlueBuild clearly, stay close to upstream wherever practical, and keep its own product opinions visible, small, and reviewable.
