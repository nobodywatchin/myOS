# Alma Drift

These are the intentional lane differences that remain after the role-first refactor.

## Alma 9

- supports `nvidia-legacy` as a first-class lane
- supports Workstation core/full and Server full
- does not support Console

## Alma 10

- supports Workstation core/full and Server full
- supports Console core preview
- supports `nvidia-open`, not `nvidia-legacy`

## Shared across both lanes

- Workstation role remains available with GNOME and COSMIC families
- optional per-user OpenClaw via `openquad` ships everywhere
- ROCm userspace stays in the shared core contract
- full images remain the only place for tenant tooling, persistent-user admin tooling, and `openclaw-host`

When adding new divergence, prefer keeping it in `recipes/layers/alma9/` or `recipes/layers/alma10/` instead of weakening the shared contracts.
