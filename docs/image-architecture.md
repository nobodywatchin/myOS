# myOS Image Architecture

## Overview

The repo is intentionally flatter now:

- shared layers for what really is shared
- one small layer set per Alma version
- one core tier per distro: `full`
- `core.yml` acts as the shared substrate and `full.yml` adds the feature-complete published core composition on top of it
- NVIDIA split into explicit `open` and `legacy` streams, plus workstation-only extras

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
    workstation/
      alma9/
        workstation.yml
        nvidia-open.yml
        nvidia-legacy.yml
      alma10/
        workstation.yml
        nvidia-open.yml
  layers/
    shared/
      core.yml
      full.yml
      workstation-base.yml
      nvidia-common.yml
      nvidia-cuda.yml
      nvidia-open.yml
      nvidia-workstation.yml
    alma9/
      core.yml
      nvidia-legacy.yml
      workstation.yml
    alma10/
      core.yml
      workstation.yml
    features/
      kubernetes-cli.yml
```

The `features/` directory still exists for composable extras, but `kubernetes-cli.yml`
is now also pulled into the published `core-full-*` image line through `shared/full.yml`.

## Core Progression

Both Alma 9 and Alma 10 now expose the same build path:

- `core-full-*`
- `core-full-*-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- workstation images on top of `core-full-*`

`core-full-*` is the single feature-complete base tier. It includes dedicated tenant tooling, persistent-user enrollment commands, Cockpit admin services, shared ROCm userspace, and OpenClaw platform-host scaffolding for both distros. CUDA repo/toolkit content comes in through the NVIDIA image paths via `shared/nvidia-cuda.yml` rather than the plain non-NVIDIA `core-full-*` images. That shared OpenClaw scaffolding includes the host-side `openquad` runtime wrapper plus the shipped per-user rootless Quadlet template. Alma 10 carries RamaLama in its distro-specific core layer; Alma 9 keeps the same platform layout without the packaged RamaLama runtime.

## Layer Responsibilities

- `recipes/layers/shared/core.yml`: earliest shared EL metadata hookup, base system, podman/runtime tooling, shared EL runtime defaults, and the shared Tailscale baseline
- `recipes/layers/shared/full.yml`: feature-complete full-core composition layered on top of `shared/core.yml`, adding platform-host scaffolding, shared AI/infrastructure tooling, Kubernetes CLI availability, shared service defaults, and late branding
- `modules/os-release-meta`: runs first from `core`, writing `/usr/share/myos/os-release-meta.env` plus the DNF `releasever_major` and `releasever_minor` vars
- `recipes/layers/alma10/core.yml`: Alma 10-specific core delta, including the optional packaged RamaLama host-service path
- `recipes/layers/shared/workstation-base.yml`: shared GNOME desktop baseline, workstation diagnostics, network/storage extras, and Flatpak defaults
- `recipes/layers/shared/nvidia-common.yml`: NVIDIA repo enablement, container toolkit, and core boot args shared by both streams
- `recipes/layers/shared/nvidia-open.yml`: open-kmod NVIDIA driver path for newer supported GPUs
- `recipes/layers/alma9/nvidia-legacy.yml`: Alma 9 proprietary older-GPU AI path pinned to `nvidia-driver:580`, using `module enable` plus package install so EL9 resolves kernel-version-specific prebuilt `kmod-nvidia-*` providers instead of DKMS
- `recipes/layers/shared/nvidia-workstation.yml`: workstation-only NVIDIA userspace extras and display-oriented kernel args
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml`: distro-specific core deltas only
- `recipes/layers/alma9/workstation.yml` and `recipes/layers/alma10/workstation.yml`: distro-specific workstation deltas on top of the shared workstation base

## Build Flow

The build workflow is ordered so workstation images wait for the full core image job.

- core images are published first
- workstation recipes use `ghcr.io/myos-dev/core-full-*` as their `base-image`
- workstation rebuilds therefore track the published full core image line instead of reassembling the whole core stack inside the workstation recipe
- NVIDIA workstation images add `nvidia-workstation.yml` on top of the published NVIDIA core images for the matching stream

## Rootless Service Model

The layering now mirrors the rootless workload split.

- `core-full-*` carries the persistent or background plane: dedicated tenant-account OpenClaw tooling, the persistent-user enrollment commands, the `openquad` host wrapper, template buckets under `/etc/myos/templates/apps/` and `/etc/myos/templates/persistent-users/`, and the shared `/var/tmp/myos-podman` rootless storage location. The per-user OpenClaw template ships under `/etc/myos/templates/apps/openclaw/user/` and is instantiated explicitly by `openquad` rather than enrolled automatically.
- `workstation-*` now reuses that same shared per-user OpenClaw runtime model instead of adding a separate session-bound helper through `/etc/skel`.
- `full.yml` disables the stock `bootc-fetch-apply-updates.*` units so update activation remains an explicit operator action across the image family.

## Migration Summary

Workstation short-name mapping is now:

- `alma9` -> `workstation-alma9`
- `alma9-nvidia-open` -> `workstation-alma9-nvidia-open`
- `alma9-nvidia-legacy` -> `workstation-alma9-nvidia-legacy`
- `alma10` -> `workstation-alma10`
- `alma10-nvidia-open` -> `workstation-alma10-nvidia-open`

Current core image set:

- `core-full-alma9`
- `core-full-alma9-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- `core-full-alma10`
- `core-full-alma10-nvidia-open`

Stream guidance:

- choose `-nvidia-open` for newer GPUs that work with the open kernel module path
- choose Alma 9 `-nvidia-legacy` for the older-GPU AI host lane when the proprietary prebuilt kernel module path is required, especially for Maxwell-, Pascal-, and similar legacy-supported hardware
- Alma 10 support in myOS is `-nvidia-open`

Legacy AI guidance:

- Alma 9 `-nvidia-legacy` keeps the host on the proprietary NVIDIA `580` driver branch and expects EL9 prebuilt kernel modules rather than DKMS.
- The host driver branch and the AI userspace stack are separate decisions; keep the host pinned to R580 even when application containers or virtual environments move independently.
- For Maxwell-, Pascal-, and similar legacy-supported GPUs, start with CUDA 12.6-class userspace stacks such as PyTorch `cu126` rather than assuming CUDA 13-era examples are the right default.
- The repo verification path should fail if the Alma 9 legacy stream ever resolves only to DKMS packages.

## Review Points

Assumptions used in this simplification:

- there is no practical value in a separate `core-ai-*` layer of published images right now
- `core-full-*` is the right default parent for workstations
- base NVIDIA images should stay leaner than workstation NVIDIA images
- the repo should expose both NVIDIA streams explicitly instead of overloading one `-nvidia` name
- Alma 9 should keep the full tenant/OpenClaw platform layout even without a bundled RamaLama package

Manual review still recommended for:

- whether Alma 9 should eventually gain an alternate AI runtime source or remain model-host-runtime-free
- whether the published `latest` core tags are the right workstation base tags for your PR workflow expectations
- whether future headless/server products should stay on `core-full-*` or eventually reintroduce a slimmer core tier
core tier
