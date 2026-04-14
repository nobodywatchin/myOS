# myOS Image Architecture

## Overview

The repo keeps the image model intentionally flat:

- shared layers for what really is shared
- one small layer set per Alma version
- one published core tier per distro: `full`
- one shared workstation base for GNOME, COSMIC, and future desktop variants
- explicit NVIDIA streams plus shared workstation-display NVIDIA extras

## Repo Tree

```text
recipes/
  images/
    core/
      alma9/
        full.yml
        full-nvidia-open.yml
        full-nvidia-legacy.yml
      alma10/
        full.yml
        full-nvidia-open.yml
    gnome/
      alma9/
        gnome.yml
        nvidia-open.yml
        nvidia-legacy.yml
      alma10/
        gnome.yml
        nvidia-open.yml
    cosmic/
      alma9/
        cosmic.yml
        nvidia-open.yml
        nvidia-legacy.yml
      alma10/
        cosmic.yml
        nvidia-open.yml
  layers/
    shared/
      core.yml
      full.yml
      workstation-common.yml
      workstation-gnome.yml
      workstation-cosmic.yml
      gnome-base.yml
      nvidia-common.yml
      nvidia-cuda.yml
      nvidia-open.yml
      nvidia-workstation.yml
      nvidia-gnome.yml
    alma9/
      core.yml
      workstation.yml
      gnome.yml
      nvidia-legacy.yml
    alma10/
      core.yml
      workstation.yml
      gnome.yml
    features/
      kubernetes-cli.yml
```

`gnome-base.yml` and `nvidia-gnome.yml` remain as thin compatibility wrappers,
but the documented first-class workstation path is now:

- `workstation-common`
- `alma*/workstation`
- one DE layer
- optional DE-specific distro drift
- optional `nvidia-workstation`

## Core Progression

Both Alma 9 and Alma 10 now expose the same build path:

- `core-full-*`
- `core-full-*-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- workstation images on top of `core-full-*`

`core-full-*` is the single feature-complete base tier. It includes dedicated
tenant tooling, persistent-user enrollment commands, Cockpit admin services,
shared ROCm userspace, the Kubernetes CLI, and OpenClaw platform-host
scaffolding for both distros. CUDA repo/toolkit content comes in through the
NVIDIA image paths via `shared/nvidia-cuda.yml` rather than the plain
non-NVIDIA `core-full-*` images. That shared OpenClaw scaffolding includes the
host-side `openquad` runtime wrapper plus the shipped per-user rootless Quadlet
template. Alma 10 carries the packaged RamaLama CLI in its distro-specific core
layer; Alma 9 keeps the same platform layout without a packaged RamaLama CLI.

## Workstation Layering

- `recipes/layers/shared/workstation-common.yml`: the DE-agnostic workstation
  base, including shared multimedia/session packages, shared Flatpak policy,
  boot-time display-manager reconciliation, desktop diagnostics/admin tooling,
  and Homebrew support
- `recipes/layers/alma9/workstation.yml` and `recipes/layers/alma10/workstation.yml`:
  distro-specific workstation drift shared by GNOME and COSMIC
- `recipes/layers/shared/workstation-gnome.yml`: shared GNOME session stack,
  GNOME payloads, GNOME Software wiring, and shared GNOME extensions
- `recipes/layers/alma9/gnome.yml` and `recipes/layers/alma10/gnome.yml`:
  GNOME-only Alma drift on top of the shared workstation base
- `recipes/layers/shared/workstation-cosmic.yml`: shared COSMIC install logic,
  version-aware `ligenix/enterprise-cosmic` COPR enablement, COSMIC session
  validation, desktop marker payloads, and COSMIC portal wiring
- `recipes/layers/shared/nvidia-workstation.yml`: workstation-display NVIDIA
  extras shared by GNOME and COSMIC workstation images

## Layer Responsibilities

- `recipes/layers/shared/core.yml`: earliest shared EL metadata hookup, base
  system, podman/runtime tooling, shared EL runtime defaults, and the shared
  Tailscale baseline
- `recipes/layers/shared/full.yml`: feature-complete full-core composition
  layered on top of `shared/core.yml`, adding platform-host scaffolding, shared
  AI/infrastructure tooling, Kubernetes CLI availability, shared service
  defaults, and late branding
- `modules/os-release-meta`: runs first from `core`, writing
  `/usr/share/myos/os-release-meta.env` plus the DNF `releasever_major` and
  `releasever_minor` vars
- `recipes/layers/shared/nvidia-common.yml`: NVIDIA repo enablement, container
  toolkit, and core boot args shared by both streams
- `recipes/layers/shared/nvidia-open.yml`: open-kmod NVIDIA driver path for
  newer supported GPUs
- `recipes/layers/alma9/nvidia-legacy.yml`: Alma 9 proprietary older-GPU AI
  path pinned to `nvidia-driver:580`, using `module enable` plus package install
  so EL9 resolves kernel-version-specific prebuilt `kmod-nvidia-*` providers
  instead of DKMS

## Build Flow

The build workflow is ordered so GNOME and COSMIC images wait for the full core
image job.

- core images are published first
- workstation recipes use `ghcr.io/myos-dev/core-full-*` as their `base-image`
- GNOME and COSMIC rebuilds therefore track the published full core image line
  instead of reassembling the whole core stack inside the workstation recipe
- workstation NVIDIA images add `nvidia-workstation.yml` on top of the matching
  published NVIDIA core images

## Rootless Service Model

The layering mirrors the rootless workload split.

- `core-full-*` carries the persistent or background plane: dedicated
  tenant-account OpenClaw tooling, the persistent-user enrollment commands, the
  `openquad` host wrapper, template buckets under `/etc/myos/templates/apps/`
  and `/etc/myos/templates/persistent-users/`, and the shared
  `/var/tmp/myos-podman` rootless storage location. The per-user OpenClaw
  template ships under `/etc/myos/templates/apps/openclaw/user/` and is
  instantiated explicitly by `openquad` rather than enrolled automatically.
- `gnome-*` and `cosmic-*` reuse that same shared per-user OpenClaw runtime
  model instead of adding separate session-bound runtime helpers through
  `/etc/skel`.
- current session-bound convenience helpers such as the Tailscale systray remain
  in the GNOME payload tree until a DE-agnostic workstation story is proven.
- `full.yml` disables the stock `bootc-fetch-apply-updates.*` units so update
  activation remains an explicit operator action across the image family.

## Image Set

Current core image set:

- `core-full-alma9`
- `core-full-alma9-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- `core-full-alma10`
- `core-full-alma10-nvidia-open`

Current workstation image set:

- `gnome-alma9`
- `gnome-alma9-nvidia-open`
- `gnome-alma9-nvidia-legacy`
- `gnome-alma10`
- `gnome-alma10-nvidia-open`
- `cosmic-alma9`
- `cosmic-alma9-nvidia-open`
- `cosmic-alma9-nvidia-legacy`
- `cosmic-alma10`
- `cosmic-alma10-nvidia-open`

GNOME remains the default documented workstation path in the main README and VM
examples, while COSMIC is now a parallel supported workstation family.

## Review Points

Assumptions used in this layering:

- `core-full-*` remains the right default parent for workstation images
- workstation-common should only contain genuinely DE-agnostic behavior
- GNOME and COSMIC should stay cleanly separated at the session/greeter/portal
  layer even when they share the same workstation substrate
- the COSMIC COPR chroot target differs by EL major version, but the COSMIC
  image family does not currently need separate Alma 9 and Alma 10 desktop
  layers beyond that repo-target logic
- workstation NVIDIA userspace extras should be shared by GNOME and COSMIC
  rather than staying GNOME-named forever

Manual review is still recommended for:

- whether the published `latest` core tags are the right workstation base tags
  for your PR workflow expectations
- whether COSMIC eventually needs a distro-specific layer beyond the current
  EL-major-aware COPR target selection
- whether future KDE support can stay within the same workstation-common plus
  DE-layer model without introducing another product tier
