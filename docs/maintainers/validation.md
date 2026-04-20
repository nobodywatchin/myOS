# Validation

Validation stays tied to the actual supported matrix.

The authoritative machine-readable source is `files/base/runtime/usr/share/myos/image-matrix.tsv`, rendered through `scripts/render-image-matrix.py` for CI. `myos rebase` downloads the same TSV path from the GitHub repo at runtime.

## Repo-local checks

Run these first:

```bash
git diff --check
bash ./scripts/validate-runtime-artifacts.sh
bash ./scripts/validate-image-matrix.sh
```

`validate-runtime-artifacts.sh` checks:

- `files/agent/runtime-core/**`
- `files/agent/platform-host/**`
- shared Vulkan packaging in `shared/core-base.yml`
- NVIDIA PCP PMDA registration payloads
- explicit AMD `uaccess` tagging in the shared DRM/KFD rule
- persistent-user GPU group enrollment wiring
- workstation DM helper wiring
- workstation Flatpak policy payloads
- host and per-user OpenClaw templates

`validate-image-matrix.sh` checks:

- the shipped image-matrix manifest parses cleanly
- the manifest recipe set exactly matches `recipes/images/**`
- retired recipes, wrapper layers, and stale payload docs stay gone
- the workflow uses manifest-driven JSON matrices for only `server-images` and `workstation-images`
- the renderer can emit per-lane recipe lists, workflow matrices, and `myos rebase` output directly from the manifest
- legacy NVIDIA naming no longer leaks into the active manifest or recipe tree
- every supported recipe inherits shared PCP exactly once through `shared/core-base.yml`
- every NVIDIA recipe inherits NVIDIA PCP exactly once through `shared/nvidia-base.yml` while standard recipes do not

## Alma 9 NVIDIA 580

When that path changes and the tooling is available, run:

```bash
pwsh ./scripts/verify-alma9-nvidia-580.ps1
```

That script derives the supported Alma 9 NVIDIA 580 recipes from the matrix manifest and verifies the lane-specific package transaction.

## CI matrix

The build workflow is single-branch and covers the full supported matrix:

- server images across Alma 9, Alma 10, and Fedora 43
- workstation images across Alma 9, Alma 10, and Fedora 43
- the Alma 9 NVIDIA 580 validator runs before any builds because that lane remains part of the supported matrix

Each build job consumes a JSON matrix rendered from the shared TSV manifest in a small `define-image-matrix` workflow job.

## Change-specific guidance

- If you change `files/base/runtime/usr/share/myos/image-matrix.tsv`, re-check validation, CI, and the online `myos rebase` picker together.
- If you change `shared/core-base.yml`, re-check every role contract and the shared PCP service contract.
- If you change `shared/core.yml` or `fedora43/core.yml`, re-check the matching distro core delta.
- If you change `shared/full.yml`, re-check server/admin docs and validation.
- If you change `shared/end-user-common.yml`, re-check workstation images together.
- If you change `shared/workstation-common.yml`, re-check both GNOME and COSMIC expectations.
- If you change the shared NVIDIA layers, re-check both the Alma and Fedora NVIDIA lanes, including NVIDIA PCP PMDA registration.
- If you change Alma-specific drift, update `docs/maintainers/alma-drift.md` in the same change.

## Runtime diagnostics

- `openquad doctor` surfaces current-session GPU group membership, device-node access, Podman runtime, and whether the shipped per-user Quadlet actually requests GPU devices.
- `myos persistent-user-validate --user NAME` checks `render`/`video` membership plus real access to `/dev/dri/renderD*` and `/dev/kfd` for enrolled login users.
