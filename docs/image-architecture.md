# myOS Image Architecture

## Overview

The repo is intentionally flatter now:

- shared layers for what really is shared
- one small layer set per Alma version
- two core tiers per distro: `minimal` and `full`
- NVIDIA split into explicit `open` and `legacy` streams, plus workstation-only extras

## Repo Tree

```text
recipes/
  images/
    core/
      alma9/
        minimal.yml
        minimal-nvidia-open.yml
        minimal-nvidia-legacy.yml
        full.yml
        full-nvidia-open.yml
        full-nvidia-legacy.yml
      alma10/
        minimal.yml
        minimal-nvidia-open.yml
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
      core-base.yml
      core-full.yml
      workstation-base.yml
      nvidia-common.yml
      nvidia-open.yml
      nvidia-workstation.yml
    alma9/
      core.yml
      nvidia-legacy.yml
      workstation.yml
    alma10/
      core.yml
      core-full.yml
      workstation.yml
    features/
      kubernetes-cli.yml
```

## Core Progression

Both Alma 9 and Alma 10 now expose the same build path:

- `core-minimal-*`
- `core-minimal-*-nvidia-open`
- `core-minimal-alma9-nvidia-legacy`
- `core-full-*`
- `core-full-*-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- workstation images on top of `core-full-*`

`core-full-*` is the single feature-complete base tier. It includes dedicated tenant tooling, persistent-user enrollment commands, Cockpit admin services, and OpenClaw platform-host scaffolding for both distros. That shared OpenClaw scaffolding now includes the host-side `openclaw` and `openquad` wrappers plus the baseline per-user rootless Quadlet template. Alma 10 adds RamaLama through a distro-specific full layer; Alma 9 keeps the same platform layout without the packaged RamaLama runtime.

## Layer Responsibilities

- `recipes/layers/shared/core-base.yml`: base system, podman/runtime tooling, branding, shared service defaults, and the disabled stock bootc auto-apply timer
- `recipes/layers/shared/core-full.yml`: shared full-core admin services, dedicated tenant CLI, persistent-user enrollment tooling, and OpenClaw platform-host scaffolding
- `recipes/layers/alma10/core-full.yml`: Alma 10-only RamaLama runtime package
- `recipes/layers/shared/workstation-base.yml`: shared workstation diagnostics, network/storage extras, and Flatpak defaults
- `recipes/layers/shared/nvidia-common.yml`: NVIDIA repo enablement, container toolkit, and core boot args shared by both streams
- `recipes/layers/shared/nvidia-open.yml`: open-kmod NVIDIA driver path for newer supported GPUs
- `recipes/layers/alma9/nvidia-legacy.yml`: Alma 9 proprietary legacy path installed through the non-DKMS `nvidia-driver:latest` module stream so userspace and prebuilt `kmod-nvidia-*` providers stay aligned
- `recipes/layers/shared/nvidia-workstation.yml`: workstation-only NVIDIA userspace extras and display-oriented kernel args
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml`: distro-specific package, tailscale, and just setup
- `recipes/layers/alma9/workstation.yml` and `recipes/layers/alma10/workstation.yml`: distro-specific workstation packaging

## Build Flow

The build workflow is ordered so workstation images wait for the full core image job.

- core images are published first
- workstation recipes use `ghcr.io/myos-dev/core-full-*` as their `base-image`
- workstation rebuilds therefore track the published full core image line instead of reassembling the whole core stack inside the workstation recipe
- NVIDIA workstation images add `nvidia-workstation.yml` on top of the published NVIDIA core images for the matching stream

## Rootless Service Model

The layering now mirrors the rootless workload split.

- `core-full-*` carries the persistent or background plane: dedicated tenant-account OpenClaw tooling, the persistent-user enrollment commands, the `openclaw` and `openquad` host wrappers, template buckets under `/etc/myos/templates/apps/` and `/etc/myos/templates/persistent-users/`, and the shared `/var/tmp/myos-podman` rootless storage location.
- `workstation-*` now reuses that same shared per-user OpenClaw runtime model instead of adding a separate session-bound helper through `/etc/skel`.
- `core-base.yml` disables the stock `bootc-fetch-apply-updates.*` units so update activation remains an explicit operator action across the image family.

## Migration Summary

Workstation short-name mapping is now:

- `alma9` -> `workstation-alma9`
- `alma9-nvidia-open` -> `workstation-alma9-nvidia-open`
- `alma9-nvidia-legacy` -> `workstation-alma9-nvidia-legacy`
- `alma10` -> `workstation-alma10`
- `alma10-nvidia-open` -> `workstation-alma10-nvidia-open`

Current core image set:

- `core-minimal-alma9`
- `core-minimal-alma9-nvidia-open`
- `core-minimal-alma9-nvidia-legacy`
- `core-full-alma9`
- `core-full-alma9-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- `core-minimal-alma10`
- `core-minimal-alma10-nvidia-open`
- `core-full-alma10`
- `core-full-alma10-nvidia-open`

Stream guidance:

- choose `-nvidia-open` for newer GPUs that work with the open kernel module path
- choose Alma 9 `-nvidia-legacy` when the proprietary prebuilt kernel module path is required, especially for Maxwell-, Pascal-, and similar legacy-supported hardware
- Alma 10 support in myOS is `-nvidia-open`

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
- whether future headless/server products should start from `core-minimal-*` or `core-full-*`
