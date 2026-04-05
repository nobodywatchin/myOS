# recipes/layers/

These files are the reusable composition units included from image recipes with `from-file:`.

## Layout

```text
layers/
  shared/
  alma9/
  alma10/
  features/
```

## Shared layers

### `shared/core-base.yml`

The shared full-core substrate.

This is not a tiny bootstrap layer despite the name. It carries the common EL identity setup, base packages, shared runtime payloads, shared platform-host scaffolding, and shared service defaults used by every `core-full-*` image.

### `shared/workstation-base.yml`

The shared workstation add-on layered on top of published `core-full-*` images.

It owns the common GNOME baseline, workstation diagnostics and utilities, shared Flatpak defaults, and workstation payload trees.

### `shared/nvidia-common.yml`

Shared NVIDIA repo enablement, container toolkit setup, and core boot args.

### `shared/nvidia-cuda.yml`

Shared CUDA repo setup plus NVIDIA-only shell/ldconfig payloads.

### `shared/nvidia-open.yml`

Shared NVIDIA open-kernel-module stream for newer supported GPUs.

### `shared/nvidia-workstation.yml`

Workstation-only NVIDIA userspace extras layered on top of the matching NVIDIA core image.

## Distro-specific layers

### `alma9/core.yml`

Alma 9-only core delta. Keep this small and limited to EL9-specific behavior.

### `alma10/core.yml`

Alma 10-only core delta. This is where the packaged RamaLama runtime currently lives.

### `alma9/workstation.yml`

Alma 9-only workstation delta on top of `shared/workstation-base.yml`.

### `alma10/workstation.yml`

Alma 10-only workstation delta on top of `shared/workstation-base.yml`.

### `alma9/nvidia-legacy.yml`

Alma 9-only proprietary NVIDIA legacy stream for older-GPU AI hosts.

## Feature layers

### `features/`

Optional capabilities that should stay opt-in instead of silently becoming part of every image.

## Reading order

When tracing an image:

1. start from `recipes/images/**`
2. follow each `from-file:` in order
3. treat later layers as additive deltas on top of earlier ones
4. expect shared layers to carry the common behavior and distro layers to stay narrow

## Editing guidance

- Prefer shared layers for truly shared behavior.
- Prefer Alma-specific layers for package or platform drift.
- Keep feature layers optional.
- If a layer is getting hard to scan, improve comments or split by concern before inventing a new product tier.
