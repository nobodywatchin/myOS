# Image Architecture

The repo still models myOS by role first, but the supported image set is now branch-oriented instead of split across workstation core/full and console variants.

## Authoritative image tree

```text
recipes/images/
  workstation/
    gnome/
      alma9/
      alma10/
      fedora43/
    cosmic/
      alma9/
      alma10/
      fedora43/
  server/
    alma9/
    alma10/
    fedora43/
```

This is the authoritative repo shape.

Internal filenames like `core.yml`, `full.yml`, and `nvidia-legacy.yml` remain maintenance details. They no longer define the public product model.

## Product model

Supported public tags are branch-scoped and short:

- `alma9` branch: `alma9-gnome-nvidia-580`, `alma9-cosmic-nvidia-580`, `alma9-server-nvidia-580`
- `alma10` branch: `alma10-gnome`, `alma10-gnome-nvidia-open`, `alma10-cosmic`, `alma10-cosmic-nvidia-open`, `alma10-server`, `alma10-server-nvidia-open`
- `fedora43` branch: `fedora43-gnome`, `fedora43-gnome-nvidia-open`, `fedora43-cosmic`, `fedora43-cosmic-nvidia-open`, `fedora43-server`

Public names follow this grammar:

- `<platform>-<environment>`
- `<platform>-<environment>-<driver>`

Unsupported combinations stay absent from recipes and CI.

## Machine-readable matrix

`files/base/runtime/usr/share/myos/image-matrix.tsv` is the authoritative supported-image manifest.

It is shipped into images at `/usr/share/myos/image-matrix.tsv` and consumed by:

- `scripts/render-image-matrix.py`
- `scripts/validate-image-matrix.sh`
- `.github/workflows/build.yml`
- `myos rebase`

The TSV schema is intentionally small and branch-aware:

- `branch`
- `job`
- `platform`
- `role`
- `environment`
- `driver`
- `image`
- `recipe`

The docs stay human-authored, but that TSV is the machine-readable source of truth for supported recipe paths, workflow matrices, and rebase targets.

## Base relationships

### Shared core substrate

`recipes/layers/shared/core.yml` is the shared boring base for every Alma image.

It owns:

- common EL identity and base packages
- base runtime defaults and branding payloads
- host Vulkan userland/tooling
- shared ROCm userspace
- shared Tailscale baseline
- optional per-user OpenClaw runtime payloads under `files/agent/runtime-core/`

`recipes/layers/fedora43/core.yml` is the Fedora 43 counterpart for the same role contract on the official Fedora BootC base.

### Admin/operator layer

`recipes/layers/shared/full.yml` is the distro-neutral admin/operator layer.

It now stacks on top of an explicit distro core instead of pulling one in implicitly, which is what allows `fedora43-server` to exist cleanly.

It owns:

- Cockpit
- OpenTofu
- Kubernetes CLI
- platform-host payloads under `files/agent/platform-host/`
- tenant, persistent-user, and `openclaw-host` filesystem scaffolding

### End-user substrate

`recipes/layers/shared/end-user-common.yml` holds workstation runtime pieces that do not belong on server images.

It owns:

- Flatpak base packaging and policy payloads
- shared end-user files under `files/end-user/shared/`

### Workstation role

`recipes/layers/shared/workstation-common.yml` remains the DE-agnostic workstation substrate.

It is followed by:

- `recipes/layers/alma9/workstation.yml` or `recipes/layers/alma10/workstation.yml`
- `recipes/layers/fedora43/workstation.yml`
- `recipes/layers/shared/workstation-gnome.yml` or `recipes/layers/shared/workstation-cosmic.yml`
- `recipes/layers/fedora43/cosmic.yml` for Fedora COSMIC-specific drift
- `recipes/layers/alma9/gnome.yml`, `recipes/layers/alma10/gnome.yml`, or `recipes/layers/fedora43/gnome.yml` for GNOME-only drift

### Server role

Server is the headless/admin/operator environment in the public naming model.

- Alma 9 server exists only on the legacy NVIDIA 580 lane.
- Alma 10 server is the stable admin/operator baseline, with optional `nvidia-open`.
- Fedora 43 server is the edge admin/operator lane without a parallel open-driver variant.

## Naming

The public tags are now uniform and short.

- no `workstation-*` prefix
- no `core-*` or `full-*` published tags
- no `default` suffix in published names
- no public `nvidia-legacy` wording; the Alma 9 lane is published as `nvidia-580`

Internal filenames may stay descriptive where that reduces churn, but the published names, matrix rows, workflow output, and rebase picker are now aligned.
