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

### `shared/core.yml`

The shared core substrate.

This carries the common EL identity setup, base packages, shared runtime defaults, and the shared Tailscale baseline used by the published `core-full-*` image line.

### `shared/full.yml`

The feature-complete shared full-core composition.

This layers on top of `shared/core.yml` and carries the platform-host scaffolding, shared AI/infrastructure tooling, Kubernetes CLI, and shared service defaults used by every `core-full-*` image.

### `shared/gnome-base.yml`

The shared GNOME desktop add-on layered on top of published `core-full-*` images.

It owns the common GNOME baseline, desktop diagnostics and utilities, shared Flatpak defaults, and GNOME payload trees.

### `shared/workstation-base.yml`

Compatibility shim that forwards to `shared/gnome-base.yml`.

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

Alma 9-only GNOME workstation delta on top of `shared/gnome-base.yml`.

### `alma10/workstation.yml`

Alma 10-only GNOME workstation delta on top of `shared/gnome-base.yml`.

### `alma9/nvidia-legacy.yml`

Alma 9-only proprietary NVIDIA legacy stream for older-GPU AI hosts.

## Feature layers

### `features/`

Composable capabilities that can be reused without inventing a new image tier. Most should stay opt-in, but a shared feature layer may also be pulled into the published full-core composition when that capability becomes part of the default operator surface.

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
