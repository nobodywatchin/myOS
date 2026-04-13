# recipes/layers/

These files are the reusable composition units included from image recipes with
`from-file:`.

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

This carries the common EL identity setup, base packages, shared runtime
defaults, and the shared Tailscale baseline used by the published `core-full-*`
image line.

### `shared/full.yml`

The feature-complete shared full-core composition.

This layers on top of `shared/core.yml` and carries the platform-host
scaffolding, shared AI/infrastructure tooling, Kubernetes CLI, and shared
service defaults used by every `core-full-*` image.

### `shared/workstation-common.yml`

The DE-agnostic workstation base layered on top of published `core-full-*`
images.

It owns the common workstation packages, shared multimedia/session tooling,
shared Flatpak policy, and desktop-wide diagnostics/admin utilities.

### `shared/workstation-gnome.yml`

The GNOME-specific workstation layer on top of `workstation-common`.

It owns the shared GNOME session stack, GNOME payload trees, GNOME Software
integration, and the cross-version-safe GNOME extension baseline.

### `shared/workstation-cosmic.yml`

The shared COSMIC workstation layer on top of `workstation-common`.

It owns the version-aware `ligenix/enterprise-cosmic` COPR enablement, COSMIC
desktop install logic, `cosmic-greeter` enablement, and COSMIC portal wiring.

### `shared/gnome-base.yml`

Compatibility wrapper that now forwards to `workstation-common.yml` and
`workstation-gnome.yml`.

### `shared/nvidia-common.yml`

Shared NVIDIA repo enablement, container toolkit setup, and core boot args.

### `shared/nvidia-cuda.yml`

Shared CUDA repo setup plus NVIDIA-only shell/ldconfig payloads.

### `shared/nvidia-open.yml`

Shared NVIDIA open-kernel-module stream for newer supported GPUs.

### `shared/nvidia-workstation.yml`

Shared workstation-display NVIDIA extras layered on top of the matching NVIDIA
core image for GNOME and COSMIC workstation images.

### `shared/nvidia-gnome.yml`

Compatibility wrapper that now forwards to `nvidia-workstation.yml`.

## Distro-specific layers

### `alma9/core.yml`

Alma 9-only core delta. Keep this small and limited to EL9-specific behavior.

### `alma10/core.yml`

Alma 10-only core delta. This is where the packaged RamaLama runtime currently
lives.

### `alma9/workstation.yml`

Alma 9-only workstation drift shared by GNOME and COSMIC.

### `alma10/workstation.yml`

Alma 10-only workstation drift shared by GNOME and COSMIC.

### `alma9/gnome.yml`

Alma 9-only GNOME delta on top of `workstation-common.yml` and
`workstation-gnome.yml`.

### `alma10/gnome.yml`

Alma 10-only GNOME delta on top of `workstation-common.yml` and
`workstation-gnome.yml`.

### `alma9/nvidia-legacy.yml`

Alma 9-only proprietary NVIDIA legacy stream for older-GPU AI hosts.

## Feature layers

### `features/`

Composable capabilities that can be reused without inventing a new image tier.
Most should stay opt-in, but a shared feature layer may also be pulled into the
published full-core composition when that capability becomes part of the default
operator surface.

## Reading order

When tracing an image:

1. start from `recipes/images/**`
2. follow each `from-file:` in order
3. treat later layers as additive deltas on top of earlier ones
4. expect shared layers to carry the common behavior and distro layers to stay
   narrow

## Editing guidance

- Prefer shared layers for truly shared behavior.
- Prefer Alma-specific workstation layers for distro drift that should affect
  more than one desktop environment.
- Prefer DE-specific shared layers for session, greeter, and portal behavior.
- Keep feature layers optional.
- If a layer is getting hard to scan, improve comments or split by concern
  before inventing a new product tier.
