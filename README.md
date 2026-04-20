<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="files/base/branding/usr/share/pixmaps/system-logo-white.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is a distro-first BootC project with a small, explicit image matrix.

Workstation remains the flagship user-facing role. Server is the headless admin/operator lane. GNOME and COSMIC are workstation environments, not separate products.

## Why myOS

- Stable where it should be: Alma 10 is the stable baseline, Fedora 43 is the edge lane, and Alma 9 is reserved for NVIDIA 580 compatibility.
- Curated image boundaries: workstation images keep the modern desktop/runtime model, while admin/operator tooling lives only in the server lane.
- Explicit GPU policy: standard images have no driver suffix, `nvidia-open` is opt-in where supported, and Alma 9 uses a dedicated `nvidia-580` lane.
- One source of truth: the repository image matrix feeds CI, validation, and `myos rebase`.
- AI-ready, not AI-bloated: ROCm userspace and host Vulkan tooling stay in the shared core contract, and optional per-user OpenClaw remains available without turning every image into a hosted platform stack.

## Supported Lanes

Public image names follow this grammar:

- `<platform>-<environment>`
- `<platform>-<environment>-<driver>`

Lane summary:

- `alma9`: NVIDIA 580 compatibility only for `gnome`, `cosmic`, and `server`
- `alma10`: stable `gnome`, `cosmic`, and `server`, with optional `nvidia-open`
- `fedora43`: edge `gnome`, `cosmic`, and `server`, with optional `nvidia-open` on workstation images

The exact supported tags live in the shipped manifest at `files/base/runtime/usr/share/myos/image-matrix.tsv` and are summarized for users in [docs/user/choose-an-image.md](docs/user/choose-an-image.md).

Unsupported by design:

- no console images
- no workstation full split
- no Alma 9 standard or `nvidia-open` images
- no `fedora43-server-nvidia-open`

## App Model

myOS keeps two Flatpak lanes on workstation images:

- user-managed `flathub` for personal installs
- admin-managed `org-system` for curated shared apps

That keeps normal app installs user-owned while still giving the image a clean place for system-wide apps the project or an admin wants to curate.

Details live in [docs/user/apps-and-flatpak.md](docs/user/apps-and-flatpak.md).

## AI-Ready

AI-ready in myOS means:

- ROCm userspace is available in the shared core contract.
- Host Vulkan tooling is available in the shared core contract.
- Optional per-user OpenClaw support via `openquad` ships in every image.
- That runtime is inert by default, user-owned, and stores mutable state in the user's home.
- Server images add the hosted/operator surfaces for tenants, persistent-user administration, and `openclaw-host`.

This is local capability, not forced hosted infrastructure and not preloaded models.

Details live in [docs/user/ai-ready.md](docs/user/ai-ready.md).

## Install And Update

The simplest way to switch images on an installed system is:

```bash
myos rebase
```

That picker is grouped by role, environment, platform, and driver.
It downloads the same image matrix from the GitHub repo that CI validates, so the supported lanes and published tags stay in sync.

For manual switching:

```bash
sudo bootc switch ghcr.io/myos-dev/alma10-gnome:latest
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
  layers/
    shared/
    alma9/
    alma10/
    fedora43/
    features/

files/
  base/
  end-user/
  workstation/
  gnome/
  cosmic/
  agent/
  dnf/
  justfiles/
```

The authoritative repo shape stays role-first. Workstation keeps clean GNOME and COSMIC layering underneath that role, while the shipped manifest decides which combinations are actually supported.

## Advanced Docs

User-facing docs start at [docs/README.md](docs/README.md).

Maintainer and operator-facing docs live under `docs/maintainers/`:

- [docs/maintainers/image-architecture.md](docs/maintainers/image-architecture.md)
- [docs/maintainers/runtime-contracts.md](docs/maintainers/runtime-contracts.md)
- [docs/maintainers/workstation-layering.md](docs/maintainers/workstation-layering.md)
- [docs/maintainers/operator-flows.md](docs/maintainers/operator-flows.md)
- [docs/maintainers/validation.md](docs/maintainers/validation.md)

Hosted OpenClaw, tenant workflows, and persistent-user administration are still supported, but they are advanced server/admin flows rather than the public identity of every image.
