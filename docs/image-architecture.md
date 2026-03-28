# myOS Image Architecture

## Overview

The repo is intentionally flatter now:

- shared layers for what really is shared
- one small layer set per Alma version
- two core tiers per distro: `minimal` and `full`
- NVIDIA split between core support and workstation-only extras

## Repo Tree

```text
recipes/
  images/
    core/
      alma9/
        minimal.yml
        minimal-nvidia.yml
        full.yml
        full-nvidia.yml
      alma10/
        minimal.yml
        minimal-nvidia.yml
        full.yml
        full-nvidia.yml
    workstation/
      alma9/
        workstation.yml
        nvidia.yml
      alma10/
        workstation.yml
        nvidia.yml
  layers/
    shared/
      core-base.yml
      core-full.yml
      workstation-base.yml
      nvidia.yml
      nvidia-workstation.yml
    alma9/
      core.yml
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
- `core-minimal-*-nvidia`
- `core-full-*`
- `core-full-*-nvidia`
- workstation images on top of `core-full-*`

`core-full-*` is the single feature-complete base tier. It includes tenant tooling, Cockpit admin services, and OpenClaw host scaffolding for both distros. Alma 10 adds RamaLama through a distro-specific full layer; Alma 9 keeps the same platform layout without the packaged RamaLama runtime.

## Layer Responsibilities

- `recipes/layers/shared/core-base.yml`: base system, podman/runtime tooling, branding, and shared service defaults
- `recipes/layers/shared/core-full.yml`: shared full-core admin services, tenant CLI, and OpenClaw host scaffolding
- `recipes/layers/alma10/core-full.yml`: Alma 10-only RamaLama runtime package
- `recipes/layers/shared/workstation-base.yml`: shared workstation diagnostics, network/storage extras, and Flatpak defaults
- `recipes/layers/shared/nvidia.yml`: NVIDIA repo enablement, driver stack, container toolkit, and core boot args
- `recipes/layers/shared/nvidia-workstation.yml`: workstation-only NVIDIA userspace extras and display-oriented kernel args
- `recipes/layers/alma9/core.yml` and `recipes/layers/alma10/core.yml`: distro-specific package, tailscale, and just setup
- `recipes/layers/alma9/workstation.yml` and `recipes/layers/alma10/workstation.yml`: distro-specific workstation packaging

## Build Flow

The build workflow is ordered so workstation images wait for the full core image job.

- core images are published first
- workstation recipes use `ghcr.io/myos-dev/core-full-*` as their `base-image`
- workstation rebuilds therefore track the published full core image line instead of reassembling the whole core stack inside the workstation recipe
- NVIDIA workstation images add `nvidia-workstation.yml` on top of the published NVIDIA core images

## Migration Summary

Existing workstation name mapping stays the same:

- `alma9` -> `workstation-alma9`
- `alma9-nvidia` -> `workstation-alma9-nvidia`
- `alma10` -> `workstation-alma10`
- `alma10-nvidia` -> `workstation-alma10-nvidia`

Current core image set:

- `core-minimal-alma9`
- `core-minimal-alma9-nvidia`
- `core-full-alma9`
- `core-full-alma9-nvidia`
- `core-minimal-alma10`
- `core-minimal-alma10-nvidia`
- `core-full-alma10`
- `core-full-alma10-nvidia`

## Review Points

Assumptions used in this simplification:

- there is no practical value in a separate `core-ai-*` layer of published images right now
- `core-full-*` is the right default parent for workstations
- base NVIDIA images should stay leaner than workstation NVIDIA images
- Alma 9 should keep the full tenant/OpenClaw platform layout even without a bundled RamaLama package

Manual review still recommended for:

- whether Alma 9 should eventually gain an alternate AI runtime source or remain model-host-runtime-free
- whether the published `latest` core tags are the right workstation base tags for your PR workflow expectations
- whether future headless/server products should start from `core-minimal-*` or `core-full-*`
