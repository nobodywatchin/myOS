# Validation

The refactor keeps validation tied to the actual supported matrix.

The authoritative machine-readable source is `files/base/runtime/usr/share/myos/image-matrix.tsv`, rendered through `scripts/render-image-matrix.py` for CI and `myos rebase`.

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
- shared Vulkan packaging in `shared/core.yml`
- explicit AMD `uaccess` tagging in the shared DRM/KFD rule
- persistent-user GPU group enrollment wiring
- workstation DM helper wiring
- the workstation Flatpak policy payloads
- the host and per-user OpenClaw templates

`validate-image-matrix.sh` checks:

- the shipped image-matrix manifest parses cleanly
- the manifest recipe set exactly matches `recipes/images/**`
- unsupported combinations stay absent because extra recipes fail validation
- retired console and workstation-full paths stay gone
- the workflow uses manifest-driven JSON matrices for only `server-images` and `workstation-images`
- each supported branch renders the expected number of server and workstation images

## Alma 9 NVIDIA 580

When that path changes and the tooling is available, run:

```bash
pwsh ./scripts/verify-alma9-nvidia-580.ps1
```

That script asserts the Alma 9 legacy NVIDIA 580 lane across:

- `alma9-server-nvidia-580`
- `alma9-gnome-nvidia-580`
- `alma9-cosmic-nvidia-580`

## CI matrix

The build workflow is branch-aware and covers only supported combinations:

- `alma9`: one server image and two workstation images, gated by runtime validation, image-matrix validation, and the NVIDIA 580 lane check
- `alma10`: two server images and four workstation images, gated by runtime validation and image-matrix validation
- `fedora43`: one server image and four workstation images, gated by runtime validation and image-matrix validation

Each build job consumes a JSON matrix rendered from the shared TSV manifest in a small `define-image-matrix` workflow job.

## Change-specific guidance

- If you change `files/base/runtime/usr/share/myos/image-matrix.tsv`, re-check validation, CI, and `myos rebase` together.
- If you change `shared/core.yml`, re-check every role contract.
- If you change `shared/full.yml`, re-check server/admin docs and validation.
- If you change `end-user-common.yml`, re-check workstation images together.
- If you change `workstation-common.yml`, re-check both GNOME and COSMIC expectations.
- If you change Alma-specific drift, update `docs/maintainers/alma-drift.md` in the same change.
- If you change the Fedora 43 lane, re-check the Fedora-specific core, server, workstation, and NVIDIA-open repo assumptions together.

## Runtime diagnostics

- `openquad doctor` surfaces current-session GPU group membership, device-node access, Podman runtime, and whether the shipped per-user Quadlet actually requests GPU devices.
- `myos persistent-user-validate --user NAME` checks `render`/`video` membership plus real access to `/dev/dri/renderD*` and `/dev/kfd` for enrolled login users.
