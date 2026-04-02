# OpenClaw tenant runtime templates

These files back the dedicated tenant-account workflow managed by `myos tenant-*`.
Each tenant is a separate rootless service account with its own home directory,
Quadlets, state, ports, secrets, and `/srv/tenants/<tenant>/` storage tree.

Contents:

- `quadlets/` contains rootless Podman unit templates that are rendered into the managed tenant account and enabled against `default.target`
- `scripts/` contains rendered helper entrypoints mounted into tenant services
- `env/` contains operator-managed runtime and secret defaults
- `storage/` documents the expected per-tenant layout
- `trust-zones/` documents the current state, storage, and secret path split for the dedicated tenant runtime
- `proxy/` contains nginx route examples that stay inactive until promoted

This directory is intentionally separate from `templates/persistent-users/`, which targets real login users rather than dedicated service accounts.
