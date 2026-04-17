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

`validate-runtime-artifacts.sh` now checks both runtime planes:

- `files/agent/runtime-core/**`
- `files/agent/platform-host/**`
- shared Vulkan packaging in `shared/core.yml`
- explicit AMD `uaccess` tagging in the shared DRM/KFD rule
- persistent-user GPU group enrollment wiring
- workstation DM helper wiring
- the end-user Flatpak policy payloads
- Console preview marker payloads
- the host and per-user OpenClaw templates

`validate-image-matrix.sh` checks:

- the shipped image-matrix manifest parses cleanly
- the manifest recipe set exactly matches `recipes/images/**`
- unsupported combinations stay absent because extra recipes fail validation
- retired top-level recipe directories stay gone
- the workflow uses manifest-driven JSON matrices for every build job
- the initial Fedora 43 workstation-core lane stays limited to GNOME/COSMIC with `default` and `nvidia-open`

## Alma 9 NVIDIA legacy

When that path changes and the tooling is available, run:

```bash
pwsh ./scripts/verify-alma9-nvidia-legacy.ps1
```

That script now asserts the legacy lane across:

- full Server
- core GNOME Workstation
- full GNOME Workstation
- core COSMIC Workstation
- full COSMIC Workstation

## CI matrix

The build workflow covers only supported combinations:

- Server full on Alma 9 and Alma 10, with supported hardware lanes
- Workstation core on Alma 9 and Alma 10, with supported families and hardware lanes
- Workstation core on Fedora 43 for GNOME and COSMIC only, with `default` and `nvidia-open`
- Workstation full on Alma 9 and Alma 10, with supported families and hardware lanes
- Console core on Alma 10, with supported hardware lanes

Each build job now consumes a JSON matrix rendered from the shared TSV manifest in a small `define-image-matrices` workflow job.

## Change-specific guidance

- If you change `files/base/runtime/usr/share/myos/image-matrix.tsv`, re-check validation, CI, and `myos rebase` together.
- If you change `shared/core.yml`, re-check every role contract.
- If you change `shared/full.yml`, re-check advanced host/operator docs and validation.
- If you change `end-user-common.yml`, re-check Workstation and Console together.
- If you change `workstation-common.yml`, re-check both GNOME and COSMIC family expectations.
- If you change Alma-specific drift, update `docs/maintainers/alma-drift.md` in the same change.
- If you change the Fedora 43 lane, re-check the Fedora-specific core, GNOME/COSMIC, and NVIDIA-open repo assumptions together.

## Runtime diagnostics

- `openquad doctor` now surfaces current-session GPU group membership, device-node access, Podman runtime, and whether the shipped per-user Quadlet actually requests GPU devices.
- `myos persistent-user-validate --user NAME` now checks `render`/`video` membership plus real access to `/dev/dri/renderD*` and `/dev/kfd` for enrolled login users.
