<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="files/base/branding/usr/share/pixmaps/system-logo-white.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is a role-first, image-based Linux project built with bootc.

It is meant to be a boring base for homelabs, self-hosted infrastructure, small internal labs, and operator workstations. The goal is not to make another flashy desktop distro. The goal is to provide reproducible system images with clear roles, predictable updates, and shared operating patterns across servers, desktops, laptops, and lab machines.

Workstation images exist so you can run the same system model on your desktop or laptop that you run on your servers. Server images are the headless infrastructure lane. GNOME and COSMIC are workstation environments, not separate products.

## Why myOS

myOS is built around a small, explicit image matrix instead of endless variants.

* **Infrastructure first:** myOS is designed for labs, servers, self-hosted systems, and operator machines.
* **Boring by design:** images should be predictable, rebuildable, and easy to reason about.
* **Role-based images:** workstation and server are the main roles. Desktop environments sit underneath the workstation role.
* **Clear platform lanes:** Alma 10 is the stable baseline, Fedora is the edge lane, and Alma 9 is reserved for NVIDIA 580 compatibility.
* **Explicit GPU policy:** standard images have no driver suffix, `nvidia-open` is opt-in where supported, and Alma 9 uses a dedicated `nvidia-580` lane.
* **One source of truth:** the repository image matrix feeds CI, validation, published tags, and `myos rebase`.
* **Local-runtime ready:** myOS includes practical host support for containers, local GPU tooling, k3s, and infrastructure workflows without baking higher-level services into the OS image.

## Supported Lanes

Public image names follow this grammar:

```text
<platform>-<environment>
<platform>-<environment>-<driver>
```

Lane summary:

* `alma9`: NVIDIA 580 compatibility only for `gnome`, `cosmic`, and `server`
* `alma10`: stable `gnome`, `cosmic`, and `server`, with optional `nvidia-open`
* `fedora`: edge `gnome`, `cosmic`, and `server`, with optional `nvidia-open` on workstation images

The exact supported tags live in the shipped manifest:

```text
files/base/runtime/usr/share/myos/image-matrix.tsv
```

User-facing image selection docs live here:

* [docs/user/choose-an-image.md](docs/user/choose-an-image.md)

Unsupported by design:

* no console images
* no workstation full split
* no Alma 9 standard images
* no Alma 9 `nvidia-open` images
* no `fedora-server-nvidia-open`

## Workstation Model

Workstation images are not a separate consumer desktop product.

They exist so your desktop or laptop can participate in the same infrastructure model as your servers:

* image-based updates
* bootc system images
* container-native workflows
* operator tooling
* predictable workstation rebuilds

GNOME and COSMIC are the supported workstation environments.

## Server Model

Server images are the headless infrastructure lane.

They are intended for lab nodes, self-hosted services, operator-managed machines, and small internal infrastructure environments.

Server images share the same core contract as workstation images where it makes sense, but avoid desktop-specific layering.

## App Model

myOS keeps two Flatpak lanes on workstation images:

* user-managed `flathub` for personal installs
* admin-managed `org-system` for curated shared apps

`org-system` is hidden from normal app and source enumeration, but remains available for system runtime dependency resolution.

This keeps normal app installs user-owned while still giving the image a clean place for system-wide apps the project or an admin wants to curate.

Details:

* [docs/user/apps-and-flatpak.md](docs/user/apps-and-flatpak.md)

## Local Runtime

myOS provides local host/runtime capability.

It does not ship hosted agents, app-hosting platforms, preloaded models, or built-in AI services.

Current shared runtime support includes:

- host Vulkan tooling where supported by the platform lane
- generic Podman capability
- k3s host capability for users who want Kubernetes on their own machines
- ROCm userspace where supported by the current platform lane, currently Alma 10 and Fedora

myOS is the base system. Higher-level services belong above it, usually in containers or k3s.

Details:

- [docs/user/ai-ready.md](docs/user/ai-ready.md)

## Install And Update

The simplest way to switch images on an installed system is:

```bash
myos rebase
```

The picker is grouped by role, environment, platform, and driver.

It downloads the same image matrix from the GitHub repo that CI validates, so supported lanes and published tags stay in sync.

For manual switching:

```bash
sudo bootc switch ghcr.io/myos-dev/alma10-gnome:latest
```

myOS disables unattended `bootc` auto-apply.

Use:

```bash
myos update-system
```

to update managed system Flatpaks, prune unused system Flatpak refs, and stage a bootc image update.

Rebase when you choose. Reboot when you are ready.

More user docs:

* [docs/user/choose-an-image.md](docs/user/choose-an-image.md)
* [docs/user/install.md](docs/user/install.md)
* [docs/user/updates-and-rollbacks.md](docs/user/updates-and-rollbacks.md)
* [docs/user/hardware.md](docs/user/hardware.md)
* [docs/user/release-policy.md](docs/user/release-policy.md)

## Repo Layout

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

User-facing docs start here:

* [docs/README.md](docs/README.md)

Maintainer and operator-facing docs live under `docs/maintainers/`:

- [docs/maintainers/image-architecture.md](docs/maintainers/image-architecture.md)
- [docs/maintainers/runtime-contracts.md](docs/maintainers/runtime-contracts.md)
- [docs/maintainers/workstation-layering.md](docs/maintainers/workstation-layering.md)
- [docs/maintainers/validation.md](docs/maintainers/validation.md)
- [docs/maintainers/alma-drift.md](docs/maintainers/alma-drift.md)

## Project Boundary

myOS is not trying to replace Fedora, AlmaLinux, Bluefin, Bazzite, or other general-purpose Linux distributions.

It is a focused image-based OS project for people who want a boring, reproducible base for servers, lab machines, and operator workstations.
