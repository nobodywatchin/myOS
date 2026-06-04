# Image Architecture

The repo models myOS by role first, and the supported image set is rendered directly from the matrix manifest.

## Authoritative image tree

```text
recipes/images/
  workstation/
    gnome/
      alma9/
      alma10/
      fedora/
    cosmic/
      alma9/
      alma10/
      fedora/
  server/
    alma9/
    alma10/
    fedora/
```

This is the authoritative repo shape.

Internal filenames like `core.yml`, `full.yml`, and `nvidia-580.yml` are maintenance details. The public product model comes from the manifest and the recipe `name:` fields.

## Product model

Public names follow this grammar:

- `<platform>-<environment>`
- `<platform>-<environment>-<driver>`

The exact supported set lives in `files/base/runtime/usr/share/myos/image-matrix.tsv`.

The renderer and CI treat that TSV as the canonical support contract for:

- published image names
- supported recipe paths
- workflow matrix expansion
- `myos rebase` output

## Machine-readable matrix

`files/base/runtime/usr/share/myos/image-matrix.tsv` is shipped into images at `/usr/share/myos/image-matrix.tsv`. `myos rebase` downloads the same path from the GitHub repo at runtime so the picker can reflect the online support matrix.

It is consumed by:

- `scripts/render-image-matrix.py`
- `scripts/validate-image-matrix.sh`
- `.github/workflows/build.yml`
- `myos rebase` through the raw GitHub copy

The TSV schema is intentionally small:

- `job`
- `platform`
- `role`
- `environment`
- `driver`
- `image`
- `recipe`

## Layer ownership

### Cross-distro core baseline

`recipes/layers/shared/core-base.yml` owns the cross-distro low-level core baseline shared by Alma and Fedora builds.

It owns:

- common core packages
- base runtime payloads and branding
- distrobox helper symlinks
- shared k3s runtime capability, service units, and kernel/network baseline through `recipes/layers/features/k3s.yml`
- shared Tailscale baseline
- shared PCP collection and local history through `pmcd.service` and `pmlogger.service`
- shared kernel args and masked system services
- shared runtime-core payloads under `files/agent/runtime-core/` such as core helper libraries, `myos cluster`, and AMD/ROCm access prerequisites

`recipes/layers/shared/core.yml` owns distro-neutral core tooling shared by every supported image. Image recipes layer it after `shared/core-base.yml` and any distro-family repository setup required for that package set.

### Distro core delta

- `recipes/layers/alma/core.yml` adds Alma-family repository and package-manager setup.
- `recipes/layers/fedora/core.yml` adds the Fedora edge-lane delta.
- `recipes/layers/alma10/core.yml` and `recipes/layers/alma9/core.yml` keep the remaining Alma-version drift after the Alma-family layer.

### Server/admin layer

`recipes/layers/shared/full.yml` is the distro-neutral admin/operator overlay.

It owns:

- Cockpit
- OpenTofu
- Kubernetes CLI
- server-only Ceph host config baseline through `recipes/layers/features/ceph-host.yml`
- platform-host payloads under `files/agent/platform-host/`
- tenant, persistent-user, and `openclaw-host` filesystem scaffolding

Server recipes now stack an explicit distro core directly into `shared/full.yml`, plus a distro-specific `ceph-host.yml` package delta when that server lane needs Ceph/RBD host modules and LVM userspace. There are no empty distro-specific `full.yml` layers left in the tree.

### Workstation layers

`recipes/layers/shared/flatpak-base.yml` owns the workstation Flatpak baseline, remotes, managed shared apps, policy payloads, session environment import hook, and cleanup helper inclusion.

`recipes/layers/shared/workstation-common.yml` owns the DE-agnostic workstation substrate.

`recipes/layers/shared/workstation-modern.yml` carries the shared workstation delta reused by the Alma 10 and Fedora lanes.

`recipes/layers/shared/workstation-gnome.yml` and `recipes/layers/shared/workstation-cosmic.yml` own environment identity and session behavior. Their nested Flatpak layers own portal backend selection and environment-specific Flatpak app/remote drift.

`recipes/layers/shared/workstation-gnome-modern.yml` carries the shared GNOME app delta reused by the Alma 10 and Fedora lanes.

Remaining distro workstation layers only add real drift:

- `alma9/workstation.yml` and `alma9/gnome.yml` for the Alma 9 compatibility lane
- `alma10/workstation.yml` and `alma10/gnome.yml` for the Alma 10 stable lane
- `alma/cosmic.yml` for Alma-family COSMIC COPR source setup shared by Alma 9 and Alma 10
- `fedora/workstation.yml` and `fedora/cosmic.yml` for Fedora edge-lane drift

### NVIDIA layers

NVIDIA ownership is split three ways:

- `shared/nvidia-base.yml`: common repo bootstrap, copied config, NVIDIA PCP PMDA wiring, and kernel args
- `shared/nvidia-common.yml` / `shared/nvidia-open.yml`: Alma-family NVIDIA lane wiring
- `fedora/nvidia-open.yml`: Fedora open-driver delta on top of the shared NVIDIA base

That keeps the repo bootstrap, copied files, NVIDIA PCP PMDA wiring, and open-driver shim owned once instead of repeated across distro layers.

## Naming

The public tags are uniform and short.

- no `workstation-*` prefix
- no `core-*` or `full-*` published tags
- no `default` suffix in published names
- no `nvidia-legacy` naming in the supported recipe tree or manifest
