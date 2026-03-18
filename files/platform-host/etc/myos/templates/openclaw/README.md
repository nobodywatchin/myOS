# OpenClaw tenant runtime templates

These files are examples for post-boot tenant provisioning.

- `quadlets/` contains rootless Podman unit templates.
- `env/` contains placeholder runtime and secret files.
- `storage/` documents the expected per-tenant layout.
- `trust-zones/` explains how Zone A, B, and C stay separated.
- `proxy/` contains nginx route examples that stay inactive until promoted.
