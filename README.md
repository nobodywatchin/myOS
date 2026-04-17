<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="files/base/branding/usr/share/pixmaps/system-logo-white.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is a distro-first BootC project built on the boring stability of AlmaLinux and shaped around a polished, hardware-aware desktop experience.

Workstation is the flagship. Server and Console are separate roles. GNOME and COSMIC are workstation families, not separate top-level products.

## Why myOS

- Stable foundation, modern experience: Alma gives us a calm long-lived base, and myOS spends the complexity budget on the image experience instead of pretending the base needs constant churn.
- Curated, not inherited: images include what fits the contract for that role and tier. Workstation does not quietly inherit Kubernetes, OpenTofu, or hosted OpenClaw admin tooling.
- Hardware policy is explicit: choose `default`, `nvidia-open`, or, on Alma 9 only, `nvidia-legacy`.
- Clean app model: system Flatpaks stay admin-managed, user Flatpaks stay user-owned, and the default UX does not bury people in duplicate catalogs.
- AI-ready, not AI-bloated: ROCm userspace and host Vulkan tooling stay in core, optional per-user OpenClaw via `openquad` ships everywhere, and hosted/operator tooling stays in full.

## Choose An Image

Every myOS image is chosen across four axes.

1. Role
   - `workstation`: the flagship desktop role.
   - `server`: full-only admin/operator role.
   - `console`: Alma 10 core-only preview role for living-room and gaming-oriented setups.
2. Tier
   - `core`: stable daily-use base without host/operator defaults.
   - `full`: adds Cockpit, OpenTofu, Kubernetes CLI, tenant tooling, persistent-user admin tooling, and `openclaw-host`.
3. Distro lane
   - `alma9`: long-lived lane with first-class NVIDIA legacy support.
   - `alma10`: newer lane with Console support and no NVIDIA legacy path.
   - `fedora43`: initial workstation-core lane on the official Fedora BootC base.
4. Hardware lane
   - `default`
   - `nvidia-open`
   - `nvidia-legacy` on Alma 9 only

### Supported Matrix

| Distro | Role | Tier | Hardware lanes |
| --- | --- | --- | --- |
| Alma 9 | Workstation | core, full | default, nvidia-open, nvidia-legacy |
| Alma 9 | Server | full | default, nvidia-open, nvidia-legacy |
| Alma 10 | Workstation | core, full | default, nvidia-open |
| Alma 10 | Server | full | default, nvidia-open |
| Alma 10 | Console | core | default, nvidia-open |
| Fedora 43 | Workstation | core | default, nvidia-open |

Unsupported by design:

- no `core/server`
- no `full/console`
- no Alma 9 Console
- no Alma 10 NVIDIA legacy
- no Fedora 43 full, server, console, or legacy NVIDIA images yet

### Workstation Families

Workstation currently has two desktop-environment implementations:

- `GNOME`: the default documented workstation path.
- `COSMIC`: a parallel supported workstation family.

Published full workstation tags keep the existing compatibility names:

- `gnome-alma10`, `gnome-alma10-nvidia-open`, `gnome-alma9`, `gnome-alma9-nvidia-open`, `gnome-alma9-nvidia-legacy`
- `cosmic-alma10`, `cosmic-alma10-nvidia-open`, `cosmic-alma9`, `cosmic-alma9-nvidia-open`, `cosmic-alma9-nvidia-legacy`

New core workstation tags are role-first:

- `workstation-core-gnome-*`
- `workstation-core-cosmic-*`

Server keeps the published compatibility tags:

- `core-full-alma10`, `core-full-alma10-nvidia-open`
- `core-full-alma9`, `core-full-alma9-nvidia-open`, `core-full-alma9-nvidia-legacy`

Console is currently published as:

- `console-core-alma10`
- `console-core-alma10-nvidia-open`

## App Model

myOS keeps two Flatpak lanes on end-user images:

- user-managed `flathub` for personal installs
- admin-managed `org-system` for curated shared apps

That keeps normal app installs user-owned while still giving the image a clean place for system-wide apps the project or an admin wants to curate.

Details live in [docs/user/apps-and-flatpak.md](docs/user/apps-and-flatpak.md).

## AI-Ready

AI-ready in myOS means:

- ROCm userspace is available in core.
- Host Vulkan tooling is available in core.
- Optional per-user OpenClaw support via `openquad` ships in every image.
- That runtime is inert by default, user-owned, and stores mutable state in the user's home.
- Full images add the hosted/operator surfaces for tenants, persistent-user administration, and `openclaw-host`.

This is local capability, not forced hosted infrastructure and not preloaded models.

Details live in [docs/user/ai-ready.md](docs/user/ai-ready.md).

## Install And Update

The simplest way to switch images on an installed system is:

```bash
myos rebase
```

That picker is now grouped by role, tier, workstation family, distro lane, and hardware lane.
It reads the same shipped image matrix that CI validates, so new supported lanes like Fedora 43 show up as first-class rebase targets without a second hard-coded list.

For manual switching:

```bash
sudo bootc switch ghcr.io/myos-dev/gnome-alma10:latest
```

myOS disables unattended `bootc` auto-apply. Update or rebase when you choose, then reboot when you are ready.

More user docs:

- [docs/user/choose-an-image.md](docs/user/choose-an-image.md)
- [docs/user/install.md](docs/user/install.md)
- [docs/user/updates-and-rollbacks.md](docs/user/updates-and-rollbacks.md)
- [docs/user/hardware.md](docs/user/hardware.md)
- [docs/user/release-policy.md](docs/user/release-policy.md)

## Repo Layout

```text
recipes/
  images/
    workstation/
    server/
    console/
  layers/
    shared/
    alma9/
    alma10/
    features/

files/
  base/
  end-user/
  workstation/
  gnome/
  cosmic/
  console/
  agent/
  dnf/
  justfiles/
```

The authoritative repo shape is now role-first. Workstation keeps clean GNOME and COSMIC family layering underneath that role.

## Advanced Docs

User-facing docs start at [docs/README.md](docs/README.md).

Maintainer and operator-facing docs live under `docs/maintainers/`:

- [docs/maintainers/image-architecture.md](docs/maintainers/image-architecture.md)
- [docs/maintainers/runtime-contracts.md](docs/maintainers/runtime-contracts.md)
- [docs/maintainers/workstation-layering.md](docs/maintainers/workstation-layering.md)
- [docs/maintainers/operator-flows.md](docs/maintainers/operator-flows.md)
- [docs/maintainers/validation.md](docs/maintainers/validation.md)

Hosted OpenClaw, tenant workflows, and persistent-user administration are still supported, but they are advanced full-tier flows rather than the public identity of every image.
