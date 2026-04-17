# Image Architecture

The repo now models myOS by role first.

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
  console/
    alma10/
```

This is the authoritative repo shape.

`recipes/images/gnome/**`, `recipes/images/cosmic/**`, and `recipes/images/core/**` are retired so the tree no longer implies that GNOME, COSMIC, or `core-full-*` are the product model.

## Product model

The supported matrix has four axes:

- distro lane: `alma9`, `alma10`, `fedora43`
- capability tier: `core`, `full`
- role: `workstation`, `server`, `console`
- hardware lane: `default`, `nvidia-open`, `nvidia-legacy` on Alma 9 only

Supported combinations:

- Alma 9 Workstation core/full, with GNOME or COSMIC, across `default`, `nvidia-open`, and `nvidia-legacy`
- Alma 9 Server full across `default`, `nvidia-open`, and `nvidia-legacy`
- Alma 10 Workstation core/full, with GNOME or COSMIC, across `default` and `nvidia-open`
- Alma 10 Server full across `default` and `nvidia-open`
- Alma 10 Console core across `default` and `nvidia-open`
- Fedora 43 Workstation core, with GNOME or COSMIC, across `default` and `nvidia-open`

Unsupported combinations stay absent from recipes and CI.

## Machine-readable matrix

`files/base/runtime/usr/share/myos/image-matrix.tsv` is the authoritative supported-image manifest.

It is shipped into images at `/usr/share/myos/image-matrix.tsv` and consumed by:

- `scripts/render-image-matrix.py`
- `scripts/validate-image-matrix.sh`
- `.github/workflows/build.yml`
- `myos rebase`

The docs stay human-authored, but that TSV is the machine-readable source of truth for supported recipe paths and rebase targets.

## Published tag compatibility

The repo tree is role-first, but the published tags keep compatibility where the tags already existed.

- full Server stays published as `core-full-*`
- full Workstation GNOME stays published as `gnome-*`
- full Workstation COSMIC stays published as `cosmic-*`
- new core Workstation tags are `workstation-core-<family>-*`
- Console preview is published as `console-core-*`

This hybrid naming is intentional. It lets the public story and repo tree move to the new model without breaking existing rebases.

## Base relationships

### Core role substrate

`recipes/layers/shared/core.yml` is the shared boring base for every Alma image.

It owns:

- common EL identity and base packages
- base runtime defaults and branding payloads
- host Vulkan userland/tooling
- shared ROCm userspace
- shared Tailscale baseline
- optional per-user OpenClaw runtime payloads under `files/agent/runtime-core/`

`recipes/layers/fedora43/core.yml` is the Fedora 43 counterpart for the same role contract on the official Fedora BootC base.

### Full tier

`recipes/layers/shared/full.yml` now means admin/operator surface, not generic "everything desktop users might want".

It owns:

- Cockpit
- OpenTofu
- Kubernetes CLI
- platform-host payloads under `files/agent/platform-host/`
- tenant, persistent-user, and `openclaw-host` filesystem scaffolding

### End-user substrate

`recipes/layers/shared/end-user-common.yml` holds end-user runtime pieces that belong on Workstation and Console but not on Server.

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

The initial Fedora lane is intentionally narrow:

- Workstation only
- core tier only
- GNOME and COSMIC families only
- `default` and `nvidia-open` hardware lanes only
- official `quay.io/fedora/fedora-bootc:43` base, not a BlueBuild/UBlue-derived base

### Console role

`recipes/layers/shared/console.yml` is intentionally small.

Console is real in the matrix, but currently scaffolded as an Alma 10 core-only preview role rather than a finished gaming shell.

## Why full Workstation still builds from published full Server

Full workstation images keep building from the published `core-full-*` images for compatibility.

That means:

- full Server is still the published parent line for full GNOME and COSMIC tags
- core Workstation and Console build directly from the AlmaLinux BootC base plus the myOS role layers
- Fedora 43 core Workstation builds directly from the official Fedora BootC base plus the Fedora-specific workstation layers

The repo now documents that as a compatibility choice instead of the public product model.
