# Contributing

## Start with the image contract

Before changing a layer, decide which role and tier should own that behavior.

- shared base behavior belongs in `recipes/layers/shared/core.yml`
- full-tier admin/operator behavior belongs in `recipes/layers/shared/full.yml`
- end-user app/runtime behavior belongs in `recipes/layers/shared/end-user-common.yml`
- workstation behavior belongs in `workstation-common` plus a workstation family layer
- distro-specific drift belongs under `recipes/layers/alma9/` or `recipes/layers/alma10/`
- optional capabilities belong under `recipes/layers/features/`

## Keep public and maintainer docs in sync

User-facing docs live under `docs/user/`.
Maintainer and operator docs live under `docs/maintainers/`.

If a change alters the supported image matrix, runtime contracts, or validation expectations, update the matching docs in the same change.

## Validation

Run the smallest meaningful set of checks for your change.

Typical local checks:

```bash
git diff --check
bash ./scripts/validate-runtime-artifacts.sh
bash ./scripts/validate-image-matrix.sh
```

If you touch Alma 9 NVIDIA legacy logic and have the tooling available:

```bash
pwsh ./scripts/verify-alma9-nvidia-legacy.ps1
```

More detail lives in [docs/maintainers/validation.md](docs/maintainers/validation.md).
